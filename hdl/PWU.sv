module PWU 
(/*AUTOARG*/
   // Outputs
   
   va_rdy_o,
   pa_o,
   pa_vld_o,
   pa_fault_o,
   pw_c_va_o,
   pw_c_vld_o,
   l1_va_o,
   l1_cancel_o,
   l1_va_vld_o,
   ch_va_o,
   ch_va_vld_o,
   // Inputs
   
   clk_i,
   resetn_i,
   va_i,
   va_vld_i,
   pa_rdy_i,
   pw_c_pa_i,
   l1_pa_i,
   l1_vld_i,
   ch_fault_i
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

   /***********REGISTER DECLARATIONS*********************/
   logic [1:0] walk_sel_reg;
   logic [3:0][1:0] walk_sel_pw00_03_reg;
   
   /***********WIRES DECLARATION*************************/
   logic walkers_ready;
   logic walkers_stall;
   
   always@(posedge clk_i)
   begin
      if (!resetn_i)
      begin
	walk_sel_reg <= 2'h0;
	 for (int i=0; i<4;i++)
	   walk_sel_pw00_03_reg[i] <= 2'h0;
      end
      else
      begin
	 if (walkers_ready && va_vld_i && !walkers_stall)
	 begin
	    walk_sel_reg <= walk_sel_reg + 1;
	 end
	 if (!walkers_stall)
	   walk_sel_pw00_03_reg <= {walk_sel_pw00_03_reg[2:0], walk_sel_reg};
      end      
   end

   




   


endmodule
