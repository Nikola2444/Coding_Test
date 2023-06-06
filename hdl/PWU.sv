module PWU 
(/*AUTOARG*/
   // Outputs
   va_rdy_o, pa_o, pa_vld_o, pa_fault_o, pw_c_va_o, pw_c_vld_o,
   l1_va_o, l1_cancel_o, l1_va_vld_o, ch_va_o, ch_va_vld_o,
   // Inputs
   clk_i, resetn_i, va_i, va_vld_i, pa_rdy_i, pw_c_pa_i, l1_pa_i,
   l1_vld_i, ch_fault_i
   );

   // synchronization inputs
   input logic clk_i;   
   input logic resetn_i;

   /*******Input Virtual address IF*********/
   // through this interface PWU receives untranslated virtual address 
   // Virtual address
   input logic [31:0] va_i;
   // input valid signal
   input logic        va_vld_i;
   // output ready signal
   output logic       va_rdy_o;

   /*******Output Physical address IF*********/
   // through this interface PWU outputs calculated physical address
   // output physical address
   output logic[27:0] pa_o;
   //output valid signal
   output logic       pa_vld_o;
   //output fault signal
   output logic       pa_fault_o;
   //input ready signal
   input logic        pa_rdy_i;


   /*******PW$ interface*********/
   //through this interface PWU receives 16 MSB bits of the PA
   //virtual address sent to PW cache
   output logic [31:0] pw_c_va_o;
   output logic        pw_c_vld_o;
   // 16 MSB bits received from PW cache
   input logic [15:0]  pw_c_pa_i;
   
   /*******L1 Cache IF*********/
   //virtual address for the L1 cache
   output logic[27:0] l1_va_o;
   //load cancel signal
   output logic       l1_cancel_o;
   //valid signal for the L1 cache virtual address
   output logic       l1_va_vld_o;
   //Address received from L1
   input logic [31:0] l1_pa_i;
   //Valid signal for the previous address
   input logic        l1_vld_i;
   /*******Checker Cache IF*********/
   //virtual address for the checker
   output logic[27:0] ch_va_o;
   //valid signal for the checker
   output logic       ch_va_vld_o;
   //Fault signal from the checker
   input logic        ch_fault_i;


   /***********INTERFACE DECLARATION END*****************/

   /***********REGISTER DECLARATIONS*********************/
   logic [1:0]      walk_sel_reg;
   logic [3:0][1:0] walk_sel_pw00_03_reg;
   logic [1:0]      walk_sel_ld04_reg;
   logic [1:0]      walk_sel_ld05_reg;
   
   /***********WIRES DECLARATION*************************/
   
   logic walkers_ready_s;
   logic walkers_stall_s;
   // WIRES CONNECTED TO WALKERS
   //output wires
   logic [3:0]       va_rdy_s;

   logic [3:0][27:0] pa_s;
   logic [3:0]       pa_vld_s;
   logic [3:0]       pa_fault_s;

   logic [3:0][31:0] pw_c_va_s;
   logic [3:0]       pw_c_vld_s;

   logic [3:0][27:0] l1_va_s;
   logic [3:0]       l1_cancel_s;
   logic [3:0]       l1_va_vld_s;

   logic [3:0][27:0] ch_va_s;
   logic [3:0]       ch_va_vld_s;

   logic [3:0]       stall_s;
   //input wires   
   logic [3:0]       va_vld_s;
   

   
   //this logic generates arbitration signal. Since walkers always generate PA
   //in the same order, arbitration is done using a simple counter which increments
   //by 1 every time a walker is given VA to translate.
   //Value of this counter(walk_sel_reg) is then propagated through all the phases (PW00-PW03-LD04-LD05).
   //Value in each phase controls MUX logic which selects which walker can use a certain interface (PW$ IF, L1 IF, Checker IF, PA OUTPUT IF)
   always_ff@(posedge clk_i)
   begin
      if (!resetn_i)
      begin
	walk_sel_reg <= 2'h0;
	 for (int i=0; i<4;i++)
	   walk_sel_pw00_03_reg[i] <= 2'h0;
      end
      else
      begin
	 if (walkers_ready_s && va_vld_i && !walkers_stall_s)
	 begin
	    walk_sel_reg <= walk_sel_reg + 1;
	 end
	 if (!walkers_stall_s)
	 begin
	    walk_sel_pw00_03_reg <= {walk_sel_pw00_03_reg[2:0], walk_sel_reg};
	    walk_sel_ld04_reg 	 <= walk_sel_pw00_03_reg[3];
	    walk_sel_ld05_reg 	 <= walk_sel_ld04_reg;
	 end
      end      
   end

   //If there is a free walker generate an output rdy signal
   assign walkers_ready_s = va_rdy_s != 0;
   assign va_rdy_o = walkers_ready_s;
   
   // combinational logic bellow selects which walker should
   // translate received VA. By giving a valid signal to walker
   // it knows when to start with translation.
   always_comb
   begin
      va_vld_s = 4'h1;
      for (int i=0; i<4; i++)
	if (walk_sel_reg == i[1:0])
	begin
	   va_vld_s[i] = 1'b1;
	   break;
	end
   end

   // PW$ arbitration logic. Multiplexers which select which walker
   // has access to PW4.
   assign pw_c_vld_o = pw_c_vld_s[walk_sel_pw00_03_reg[0]];
   assign pw_c_va_o  = pw_c_va_s[walk_sel_pw00_03_reg[0]];
   //Checker and L1 cache arbitration logic. Multiplexers which select which walker
   // has access to L1 cache and L1 Checker
   assign l1_va_o     = l1_va_s[walk_sel_pw00_03_reg[2]];
   assign l1_va_vld_o = l1_va_vld_s[walk_sel_pw00_03_reg[2]];
   assign ch_va_o = ch_va_s[walk_sel_pw00_03_reg[2]];
   assign ch_va_vld_o = ch_va_vld_s[walk_sel_pw00_03_reg[2]];
   //L1 cancel arbitration logic. Mux that selects which walker can
   //cancel a load
   assign l1_cancel_o = l1_cancel_s[walk_sel_pw00_03_reg[3]];
   
   
   // If one walker generates a stall signal, stall all the other walkers
   assign walkers_stall_s = stall_s != 0;

   generate
      for (genvar i=0; i<4; i++)
      begin
	 walker walker_inst(/*AUTO_INST*/
			    // Outputs
			    .va_rdy_o		(va_rdy_s[i]),
			    .pa_o		(pa_s[i][27:0]),
			    .pa_vld_o		(pa_vld_s[i]),
			    .pa_fault_o		(pa_fault_s[i]),
			    .pw_c_va_o		(pw_c_va_s[i][31:0]),
			    .pw_c_vld_o		(pw_c_vld_s[i]),
			    .l1_va_o		(l1_va_s[i][27:0]),
			    .l1_cancel_o	(l1_cancel_s[i]),
			    .l1_va_vld_o	(l1_va_vld_s[i]),
			    .ch_va_o		(ch_va_s[i][27:0]),
			    .ch_va_vld_o	(ch_va_vld_s[i]),
			    .stall_o		(stall_s[i]),
			    // Inputs
			    .clk_i		(clk_i),
			    .resetn_i		(resetn_i),
			    .stall_i		(walkers_stall_s),
			    .va_i		(va_i[31:0]),
			    .va_vld_i		(va_vld_s[i]),
			    .pa_rdy_i		(pa_rdy_i),
			    .pw_c_pa_i		(pw_c_pa_i[15:0]),
			    .l1_pa_i		(l1_pa_i[31:0]),
			    .l1_vld_i		(l1_vld_i),
			    .ch_fault_i		(ch_fault_i));
      end

      //Output PA arbitration. Multiplexers which select a walker
      //that has access to Output Physical address IF.
      assign pa_o       = pa_s[walk_sel_ld05_reg];
      assign pa_vld_o   = pa_vld_s[walk_sel_ld05_reg];
      assign pa_fault_o = pa_fault_s[walk_sel_ld05_reg];
   endgenerate

   


   


endmodule
