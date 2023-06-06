module PWU_tb();

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   logic [27:0]		ch_va_o;		// From DUT of PWU.v
   logic		ch_va_vld_o;		// From DUT of PWU.v
   logic		l1_cancel_o;		// From DUT of PWU.v
   logic [27:0]		l1_va_o;		// From DUT of PWU.v
   logic		l1_va_vld_o;		// From DUT of PWU.v
   logic		pa_fault_o;		// From DUT of PWU.v
   logic [31:0]		pa_o;			// From DUT of PWU.v
   logic		pa_vld_o;		// From DUT of PWU.v
   logic [31:0]		pw_c_va_o;		// From DUT of PWU.v
   logic		pw_c_vld_o;		// From DUT of PWU.v
   logic		va_rdy_o;		// From DUT of PWU.v

   logic       clk_i=0;
   logic       resetn_i;
   logic [31:0]va_i=1;
   logic       va_vld_i;
   logic       pa_rdy_i;
   logic [15:0]pw_c_pa_i=0;
   logic [31:0]l1_pa_i;
   logic       l1_vld_i;
   logic       ch_fault_i;
   // End of automatics

   PWU DUT(/*AUTOINST*/
	   // Outputs
	   .va_rdy_o			(va_rdy_o),
	   .pa_o			(pa_o[31:0]),
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
	   .l1_vld_i			(l1_vld_i),
	   .ch_fault_i			(ch_fault_i));

   always
   begin
      #5ns clk_i = ~clk_i;
   end

   initial
   begin
      resetn_i = 1'b0;
      #100ns;
      resetn_i 	 = 1'b1;
      pa_rdy_i 	 = 1'b1;
      va_vld_i 	 = 1'b1;
      l1_vld_i   = 1'b1;
      ch_fault_i = 1'b1;
   end
   logic [31:0] l1_value;
   always@(posedge clk_i)
   begin
      if (resetn_i)
      begin
	 if (va_vld_i && va_rdy_o)
	   va_i    <= $urandom_range(1, 10);
	 else
	   va_i    <= 32'h0;
	 if (pw_c_vld_o)
	   pw_c_pa_i <= $urandom_range(1, 10);
	 else
	   pw_c_pa_i <= 16'h0;
	 l1_value<=$urandom_range(10, 20);
      end
   end
   assign l1_pa_i = l1_vld_i ? l1_value : 32'h0;
endmodule
