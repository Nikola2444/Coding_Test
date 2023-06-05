module walker(/*AUTOARG*/
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
   output logic[31:0] pa_o;
   //output valid signal
   output logic       pa_vld_o;
   //output fault signal
   output logic       pa_fault_o;
   //input ready signal
   input logic        pa_rdy_i;


   /*******PW$ interface*********/
   //through this interface PWU receives 16 MSB bits of the PA
   // virtual address sent to PW cache
   output logic [31:0] pw_c_va_o;
   output logic        pw_c_vld_o;
   // 16 MSB bits received from PW cache
   input logic [15:0]  pw_c_pa_i;
   
   /*******L1 Cache IF*********/
   //virtual address for the L1 cache
   output logic[27:0] l1_va_o;
   output logic       l1_cancel_o;
   //valid signal for the L1 cache virtual address
   output logic       l1_va_vld_o;
   input logic [31:0] l1_pa_i;
   input logic        l1_vld_i;
   /*******Checker Cache IF*********/
   //virtual address for the L1 checker
   output logic[27:0] ch_va_o;
   //valid signal for the L1 cache virtual address
   output logic       ch_va_vld_o;
   input logic        ch_fault_i;

   /***********INTERFACE DECLARATION END*****************/

   /*******************REGISTER DECLARATIONS*************/
   // reg for input virtual address
   logic [31:0] va_reg;
   // registers for valid signal in pw00-pw03 pipe stages
   logic [3:0]  pw00_03_va_vld_reg;
   // registers for valid signal in load phases
   logic        ld04_va_vld_reg;
   logic        ld05_va_vld_reg;
   // register in which we capture cancel from checker
   logic [1:0]  cancel_fault_reg;
   // register for data coming out of PW$
   logic [27:0] ld_va_reg;
   logic        va_rdy_reg;

   /******************WIRES DECLARATION******************/
   logic stall;

   
   
   
   //Address for PW$
   assign pw_c_va_o = va_reg;
   // valid signal for PW$
   assign pw_c_vld_o = pw00_03_va_vld_reg[0];

   //Process that implements sequential logic that trachs va_vld_i through pw00-pw03 pipe phases
   //and registers va_i until data is fetched from L1
   always_ff@(posedge clk_i)
   begin
      if (!resetn_i)
      begin
	 va_reg <= 32'h0;
	 pw00_03_va_vld_reg <= 4'h0;
	 ld_va_reg <= 28'h0;
      end
      else
      begin
	 if (!stall)
	 begin
	    if (va_vld_i && va_rdy_reg)//keep va_i until the next valid va
	    begin
	       va_reg <= va_i;
	    end
	      
	    //tracking va_vld_i throgh stages
	    pw00_03_va_vld_reg[3:0] <= {pw00_03_va_vld_reg[2:0], va_vld_i && va_rdy_o};
	    //Registering data coming out of PW$
	    ld_va_reg <= {pw_c_pa_i, va_reg[11:0]};
	    
	 end
      end
   end

   // Sequential logic used for generating ready signal for the walker   
   assign va_rdy_o = va_rdy_reg;
   always @(posedge clk_i)
   begin
      if (!resetn_i)		 
	va_rdy_reg <= 1'b1;
      else
	if (!stall)
	begin	    
	   if (va_vld_i && va_rdy_reg)//we rest rdy until we finish extracting data from L1 cache
	     va_rdy_reg <= 1'b0;
	   else if (!va_rdy_reg && pa_rdy_i)
	     va_rdy_reg <= 1'b1;	      	    	    
	end
   end

   
   //sending data to l1 cache
   assign l1_va_o     = ld_va_reg;
   //sending valid to l1 cache
   assign l1_va_vld_o = pw00_03_va_vld_reg[2];

   //sending data to checker
   assign ch_va_o = ld_va_reg;
   //sending valid to checker
   assign ch_va_vld_o = pw00_03_va_vld_reg[2];
   // We cancel load if checker generated a fault and there was a valid address in pw03 stage
   assign l1_cancel_o = ch_fault_i && pw00_03_va_vld_reg[3];

   //Sequential logic used for tracking valid and cancel signal through LD04 and LD05 stages
   always@(posedge clk_i)
   begin
      if (!resetn_i)
      begin
	 cancel_fault_reg <= 2'b0;
	 ld04_va_vld_reg <= 1'b0;
	 ld05_va_vld_reg <= 1'b0;
      end
      else if (!stall)
      begin
	 if (pw00_03_va_vld_reg[3])
	   cancel_fault_reg[0] <= l1_cancel_o;
	 
	 
	 ld04_va_vld_reg <= pw00_03_va_vld_reg[3];
	 if (!ld05_va_vld_reg && (cancel_fault_reg[0] || l1_vld_i))
	 begin
	    ld05_va_vld_reg <= 1'b1;
	    cancel_fault_reg[1] <= cancel_fault_reg[0];
	 end
	 else if (ld05_va_vld_reg && pa_rdy_i)
	   ld05_va_vld_reg <= 1'b0;
      end
   end

   // Stall signal is generated if there was no canceling of load in previous cycle,   
   // L1 cache has not outputed valid data and there is a valid address in LD04 phase
   assign stall = !cancel_fault_reg[0] && !l1_vld_i && ld04_va_vld_reg;


   always @(posedge clk_i)
   begin
      if (!resetn_i)
      begin
	 pa_o <= 32'h0;
      end
      else
      begin
	 pa_o <= l1_pa_i;
      end
   end
   assign pa_vld_o = ld05_va_vld_reg;
   assign pa_fault_o = cancel_fault_reg[1];

   
      
   



endmodule
