`include "uvm_macros.svh"
import uvm_pkg::*;

//                                         Transaction             
typedef enum bit [1:0] {RESET=0, WRITE=1, READ=2} op_t;


class transaction extends uvm_sequence_item;

    rand bit [7:0] data;  // For write operation
    rand bit [7:0] addr;    // For read operation
    op_t op;           // 1 for write, 0 for read
    logic [7:0] dout;
    bit [7:0] read_data;        // For read operation
    bit cs;

    // Constraints
    constraint cs_c {
        cs == 0;  // Active low
    }
    
    constraint addr_c {
      addr inside {[0:10]};
    }

       `uvm_object_utils_begin(transaction)
 
        `uvm_field_int(cs, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_enum(op_t, op, UVM_DEFAULT)
        `uvm_field_int(read_data, UVM_ALL_ON)
  
    `uvm_object_utils_end

  function new(string name = "transaction");
        super.new(name);
    endfunction

    // Custom print function
    function string convert2string();
      return $sformatf("op=%0b cs=%0b data=0x%4h addr=0x%2h read_data=0x%2h",op, cs,data, addr, read_data);
    endfunction
  
endclass
//--------------------------------------------------------------------------------------------------
//                                                Reset 

class reset extends uvm_sequence#(transaction);  
  `uvm_object_utils(reset)

  transaction tr;

  function new(string name = "write");
    super.new(name);
  endfunction
  
  virtual task body();
    
    
      begin
      
        tr = transaction::type_id::create("tr");
        tr.addr_c.constraint_mode(1);   //  Active     constaint
        
        start_item(tr);
      
         assert(tr.randomize);    
         tr.op = RESET;//   tr.op=0  for reset 
        
        finish_item(tr);
        
      end
  endtask  
   
     
endclass





//--------------------------------------------------------------------------------------------------
//                                                Write   Date 


class write extends uvm_sequence#(transaction);  
  `uvm_object_utils(write)
    
  transaction tr;

  function new(string name = "write");
    super.new(name);
  endfunction
  
  virtual task body();
    
    repeat(15)
      begin
      
        tr = transaction::type_id::create("tr");
        tr.addr_c.constraint_mode(1);   //  Active     constaint
        
        start_item(tr);
      
        assert(tr.randomize);    
        tr.op = WRITE;//   tr.op=1  for Write 
        
        finish_item(tr);
        
      end
  endtask  
   
     
endclass

// -------------------------------------------------------------------------------------------------
//                                                  Read  DAta 
class read extends uvm_sequence#(transaction);  
  `uvm_object_utils(read)
  transaction tr;
  function new(string name = "read");
        super.new(name);
    endfunction
//    task 
   virtual task body();
    
    repeat(15)
      begin
        tr = transaction::type_id::create("tr");
        tr.addr_c.constraint_mode(1);   //  Active     constaint
        
        start_item(tr);
      
        assert(tr.randomize);
        tr.op = READ;//   tr.op=-1   for  Read 
        
        finish_item(tr);
        
        end
    endtask
endclass
//--------------------------------------------------------------------------------------------------------------------
//                                                   Driver 
class driver extends uvm_driver #(transaction);
    `uvm_component_utils(driver)
    
    virtual spi_i vif;
    transaction tr;
    logic [15:0] data; ////<- din , addr ->
    logic [7:0] datard;
//    new
    function new(string name = "driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction
//  build_phase
 virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = transaction::type_id::create("tr");
        if(!uvm_config_db#(virtual spi_i)::get(this, "", "vif", vif))
            `uvm_fatal("DRIVER", "Could not get vif")
    endfunction

 //                                  reset task
  task reset_dut(); 
    begin
    vif.rst      <= 1'b1;  ///active high reset
    vif.cs       <= 1'b1;
    vif.miso     <= 1'b0;
      `uvm_info("DRV", "SYSTEM RESET DETECTED", UVM_MEDIUM);
    @(posedge vif.clk);
    end
  endtask
  
  //                                  write 
  task write_d();

  vif.rst  <= 1'b0;
  vif.cs   <= 1'b0;
  vif.miso <= 1'b0;
  data     = {tr.data, tr.addr};
    `uvm_info("DRV", $sformatf("DATA WRITE addr : %0d data : %0d",tr.addr, tr.data), UVM_MEDIUM); 
  @(posedge vif.clk);
  vif.miso <= 1'b1;  ///write operation
  @(posedge vif.clk);
  
  for(int i = 0; i < 16 ; i++)
   begin
   vif.miso <= data[i];
   @(posedge vif.clk);
   end

  @(posedge vif.op_done);

  endtask 
  
 //                                    Read operation 
  task read_d();

   vif.rst  <= 1'b0;
   vif.cs   <= 1'b0;
   vif.miso <= 1'b0;
   data     = {8'h00, tr.addr};  //   upper 8 bits  =0000_0000_adder_adder   
   @(posedge vif.clk);
   vif.miso <= 1'b0;  ///read operation
   @(posedge vif.clk);
  
   for(int i = 0; i < 8 ; i++)
   begin
   vif.miso <= data[i];
   @(posedge vif.clk);
   end
   
  @(posedge vif.ready);
  
   for(int i = 0; i < 8 ; i++)
   begin
   @(posedge vif.clk);
   datard[i] = vif.mosi;
   end
   `uvm_info("DRV", $sformatf("DATA READ addr : %0d dout : %0d",tr.addr,datard), UVM_MEDIUM);  
  @(posedge vif.op_done);
  
  endtask 
         
    virtual task run_phase(uvm_phase phase);
    forever begin
     
     seq_item_port.get_next_item(tr);
     
     
      if(tr.op ==  RESET)
                          begin
                          reset_dut();
                          end

      else if(tr.op == WRITE)
                          begin
                          write_d();
                          end
      else if(tr.op ==  READ)
                          begin
					      read_d();
                          end
                          
       seq_item_port.item_done();
     
   end
  endtask
      endclass

//                                                               Monitor
class monitor extends uvm_monitor;
  `uvm_component_utils(monitor)
    
    virtual spi_i vif;
    logic [15:0] din;
    logic [7:0] dout;
    uvm_analysis_port #(transaction)  send;
    transaction tr;
 //   new
  function new(string name = "monitor" , uvm_component parent = null);
        super.new(name, parent);
   endfunction
//  build
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = transaction::type_id::create("tr");                    
        send = new("send", this);
        if(!uvm_config_db#(virtual spi_i)::get(this, "", "vif", vif))
            `uvm_fatal("MONITOR", "Could not get vif")
    endfunction
    
//  task     
    virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);
      
      if(vif.rst)
        begin
        tr.op      = RESET; 
        `uvm_info("MON", "SYSTEM RESET DETECTED", UVM_NONE);
        send.write(tr);
        end
        
        
      else begin @(posedge vif.clk);
        if(vif.miso && !vif.cs) begin
                   				    tr.op = WRITE;
                  				    @(posedge vif.clk);
              
                   				   for(int i = 0; i < 16 ; i++)
                  			       begin
                     				  din[i]  <= vif.miso; 
                     				  @(posedge vif.clk);
                    			   end
                       
                   			    	    tr.addr = din[7:0];
                     				    tr.data  = din[15:8];
                       
                      @(posedge vif.op_done);
                     `uvm_info("MON", $sformatf("DATA WRITE addr:%0d data:%0d",din[7:0],din[15:8]), UVM_NONE); 
                      send.write(tr);
               end else if (!vif.miso && !vif.cs)  begin
                           
                             tr.op = READ; 
                             @(posedge vif.clk);
                             
                               for(int i = 0; i < 8 ; i++)
                               begin
                               din[i]  <= vif.miso;  
                               @(posedge vif.clk);
                               end
                               tr.addr = din[7:0];
                               
                              @(posedge vif.ready);
                              
                              for(int i = 0; i < 8 ; i++)
                              begin
                              @(posedge vif.clk);
                              dout[i] = vif.mosi;
                              end
                               @(posedge vif.op_done);
                              tr.dout = dout;  
                             `uvm_info("MON", $sformatf("DATA READ addr:%0d data:%0d ",tr.addr,tr.dout), UVM_NONE); 
                             send.write(tr);
                                                 end      
    end
end
   endtask 

endclass      


    
//                                                                 Scoreboard
      
class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard)
  uvm_analysis_imp#(transaction,scoreboard) rec;
 
  bit [31:0] mem[32] = '{default:0};
  bit [31:0] addr    = 0;
  bit [31:0] data_rd = 0;
 
// new 

  function new(string name = "sco", uvm_component parent = null);
        super.new(name, parent);
       endfunction
//  build phase 
  
  
    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    rec = new("rec", this);
    endfunction
 
//  write
  virtual function void write(transaction tr);
    if(tr.op == RESET)
              begin
                `uvm_info("SCO", "SYSTEM RESET DETECTED", UVM_NONE);
              end  
    else if (tr.op == WRITE)
      begin
        mem[tr.addr] = tr.data;
        `uvm_info("SCO", $sformatf("DATA WRITE OP  addr:%0d, wdata:%0d arr_wr:%0d",tr.addr,tr.data,  mem[tr.addr]), UVM_NONE);
      end
 
    else if (tr.op == READ)
                begin
                  data_rd = mem[tr.addr];
                  if (data_rd == tr.dout)
                    `uvm_info("SCO", $sformatf("DATA MATCHED : addr:%0d, rdata:%0d",tr.addr,tr.dout), UVM_NONE)
                         else
                     `uvm_info("SCO",$sformatf("TEST FAILED : addr:%0d, rdata:%0d data_rd_arr:%0d",tr.addr,tr.dout,data_rd), UVM_NONE) 
                end
     
  
                           $display("---------------------------------------------------------------------------");
    endfunction
endclass

//                                                              Agent
class agent extends uvm_agent;
    `uvm_component_utils(agent)
    
    driver drv;
    monitor mon;
    uvm_sequencer#(transaction) seqr;

//    New
   function new(string name = "agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction
  
//  build_phase
  
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = monitor::type_id::create("mon", this);
        drv = driver::type_id::create("drv",this);
        seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this);
        endfunction
//  connect 
  
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
        endfunction
  
endclass

// Environment
                  
// Environment
class env extends uvm_env;
    `uvm_component_utils(env)
    
    agent ag;
    scoreboard sco;

    // new
    function new(string name = "env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // build_phase
virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ag = agent::type_id::create("ag", this);
        sco= scoreboard::type_id::create("sco", this);
    endfunction

    // connect
virtual function void connect_phase(uvm_phase phase);
  ag.mon.send.connect(sco.rec);
    endfunction
endclass

// Base Test
class test extends uvm_test;
    `uvm_component_utils(test)
    
    env e;
    reset r;
    write w;
    read  d;
  
    // new
    function new(string name = "test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
  
    // build_phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        e = env::type_id::create("e", this);
        r = reset::type_id::create("r");
        w = write::type_id::create("w");
        d = read::type_id::create("d");
    endfunction

    // run_phase
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
       r.start(e.ag.seqr);
        w.start(e.ag.seqr);
        d.start(e.ag.seqr);
        phase.drop_objection(this);
    endtask
endclass  // <-- Added this missing endclass

// Top Module
module top;      
    bit clk;
    bit rst;

    // Clock generation
    initial begin
    vif.clk <= 0;
    end
        always  #10 vif.clk = ~vif.clk;

    // Instantiate the interface
    spi_i vif();

    // DUT instance
    spi_mem dut (
      .clk(vif.clk),
      .rst(vif.rst),
      .cs(vif.cs),
      .miso(vif.miso),
      .ready(vif.ready),
      .mosi(vif.mosi),
      .op_done(vif.op_done)
    );

    // Test execution
    initial begin
        // Set interface in config DB
        uvm_config_db#(virtual spi_i)::set(null, "*", "vif", vif);
        
        // Run tests
    run_test("test");
    end

    /*// Reset generation (optional)
    initial begin
        rst = 1;
        vif.rst = 1;
        #20;
        rst = 0;
        vif.rst = 0;
    end
    */

    // Dump waves
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, top);
    end
endmodule
