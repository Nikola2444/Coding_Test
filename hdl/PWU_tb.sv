//------------------------------------------------------------------------------
// File name   : PWU_tb.sv
// Author      : Nikola Kovacevic 
// Created     : 5-Aug-2023
// Description : Simple TB used for testing PWU module
// Notes       : 
//------------------------------------------------------------------------------ 
module PWU_tb();

   /*AUTOWIRE*/
   // Beginning of automatic wires (for PWU.sv)
   logic [27:0]		ch_va_o;		// From DUT of PWU.sv
   logic		ch_va_vld_o;		// From DUT of PWU.sv
   logic		l1_cancel_o;		// From DUT of PWU.sv
   logic [27:0]		l1_va_o;		// From DUT of PWU.sv
   logic		l1_va_vld_o;		// From DUT of PWU.sv
   logic		pa_fault_o;		// From DUT of PWU.sv
   logic [27:0]		pa_o;			// From DUT of PWU.sv
   logic		pa_vld_o;		// From DUT of PWU.sv
   logic [31:0]		pw_c_va_o;		// From DUT of PWU.sv
   logic		pw_c_vld_o;		// From DUT of PWU.sv
   logic		va_rdy_o;		// From DUT of PWU.sv

   logic                clk_i=0;
   logic                resetn_i;
   logic [31:0]         va_i=28'h0010000;
   logic                va_vld_i;
   logic                pa_rdy_i;
   logic [15:0]         pw_c_pa_i=0;
   logic [31:0]         l1_pa_i;
   logic                l1_pa_vld_i=0;
   logic                ch_fault_i=0;
   
   // Module instantiation
   PWU DUT(/*AUTOINST*/
	   // Outputs
	   .va_rdy_o			(va_rdy_o),
	   .pa_o			(pa_o[27:0]),
	   .pa_vld_o			(pa_vld_o),
	   .pa_fault_o			(pa_fault_o),
	   .pw_c_va_o			(pw_c_va_o[31:0]),
	   .pw_c_vld_o			(pw_c_vld_o),
	   .l1_va_o			(l1_va_o[27:0]),
	   .l1_cancel_o			(l1_cancel_o),
	   .l1_va_vld_o			(l1_va_vld_o),
	   .ch_va_o			(ch_va_o[27:0]),
	   .ch_va_vld_o			(ch_va_vld_o),
	   // Inputs
	   .clk_i			(clk_i),
	   .resetn_i			(resetn_i),
	   .va_i			(va_i[31:0]),
	   .va_vld_i			(va_vld_i),
	   .pa_rdy_i			(pa_rdy_i),
	   .pw_c_pa_i			(pw_c_pa_i[15:0]),
	   .l1_pa_i			(l1_pa_i[31:0]),
	   .l1_pa_vld_i			(l1_pa_vld_i),
	   .ch_fault_i			(ch_fault_i));


   
   //clock generator
   always
   begin
      #5ns clk_i = ~clk_i;
   end
   // intial block resets the system and sets some of the signals to constant values
   initial
   begin
      resetn_i = 1'b0;
      #100ns;
      resetn_i 	 = 1'b1;
      pa_rdy_i 	 = 1'b1;
      va_vld_i 	 = 1'b1;
      //l1_vld_i   = 1'b0;      
   end

   // logic that generates valid signal from L1 cache. 
   int limit;
   logic l1_va_vld_reg;
   event l1_va_vld;
   logic l1_va_vld_queue[$];
   always
   begin
      @(posedge clk_i);
      #1;
      if (l1_va_vld_queue.size()>0)
      begin
	 limit = $urandom_range(1, 5);
 	 l1_pa_vld_i = $urandom_range(0, 1);
	 for (int i=0; i<limit; i++)
	 begin
	    @(posedge clk_i);
	 end
	 l1_pa_vld_i   = 1'b1;
      end
      else
	l1_pa_vld_i    = 1'b0;
   end
   // we need to remember every cache request
   always@(posedge clk_i)
   begin
      if (l1_va_vld_o)
	l1_va_vld_queue.push_back(1);
   end
   
   // logic below generates values for:
   // --va_i      - virtual addr for translation
   // --pw_c_pa_i - address read from PW$
   // --l1_value  - data read from L1 cache
   // --ch_fault_i- fault generated by the checker
   logic [31:0] l1_value=0;
   always@(posedge clk_i)
   begin
      if (resetn_i)
      begin
	 if (va_vld_i && va_rdy_o)
	 begin
	    va_i[31:16] <= $urandom_range(1, 10);
	    va_i[15:0] 	<= 0;
	 end
	 else
	   va_i    <= 32'h00010000;
	 if (pw_c_vld_o)
	   pw_c_pa_i <= $urandom_range(1, 10);
	 else
	   pw_c_pa_i <= 16'h0;
	 if (l1_va_vld_o)
	 begin
	    l1_value[31:12]<=$urandom_range(0, 1);//insert a fault once in a while in L1 cache data	 
	    l1_value[11:0]<=$urandom_range(10, 20);
	 end
	 if (ch_va_vld_o)
	   ch_fault_i <= $urandom_range(0, 1);
      end
   end
   assign l1_pa_i = l1_value;

endmodule
