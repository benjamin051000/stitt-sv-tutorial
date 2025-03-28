// Greg Stitt
// University of Florida

// In this example, we fully parameterize the monitor to handle different widths
// for the data and sideband signals.

`ifndef _AXI4_STREAM_MONITOR_SVH_
`define _AXI4_STREAM_MONITOR_SVH_

`include "uvm_macros.svh"
import uvm_pkg::*;

class axi4_stream_monitor #(
    parameter int DATA_WIDTH = axi4_stream_pkg::DEFAULT_DATA_WIDTH,
    parameter int ID_WIDTH   = axi4_stream_pkg::DEFAULT_ID_WIDTH,
    parameter int DEST_WIDTH = axi4_stream_pkg::DEFAULT_DEST_WIDTH,
    parameter int USER_WIDTH = axi4_stream_pkg::DEFAULT_USER_WIDTH
) extends uvm_monitor;
    // We have to pass all parameters when registering the class.
    `uvm_component_param_utils(axi4_stream_monitor#(DATA_WIDTH, ID_WIDTH, DEST_WIDTH, USER_WIDTH))

    // We now have a fully parameterized virtual interface.
    virtual axi4_stream_if #(DATA_WIDTH, ID_WIDTH, DEST_WIDTH, USER_WIDTH) vif;

    // In the previous example, the monitor only sent the data, but now it has
    // to include all sideband information. Do support this, we send a sequence
    // item through the analysis port in case the sideband information is needed.
    uvm_analysis_port #(axi4_stream_seq_item #(DATA_WIDTH, ID_WIDTH, DEST_WIDTH, USER_WIDTH)) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);

        // Create the anaylsis port.
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
        // We need all the parameters when creating a sequence item.
        axi4_stream_seq_item #(DATA_WIDTH, ID_WIDTH, DEST_WIDTH, USER_WIDTH) item;

        forever begin
            @(posedge vif.aclk iff vif.tvalid && vif.tready);

            // The new has to be done within the loop. The write essentially 
            // sends a pointer instead of a copy, so if we change the data
            // on the next iteration, it could corrupt what has been sent
            // through the analysis port. Instead, we need to make sure that
            // every item sent is a new item. SystemVerilog has garbage
            // collection, so you don't need to worry about deleting the items.
            item       = new();
            item.tdata = vif.tdata;
            item.tstrb = vif.tstrb;
            item.tkeep = vif.tkeep;
            item.tlast = vif.tlast;
            item.tid   = vif.tid;
            item.tdest = vif.tdest;
            item.tuser = vif.tuser;
            ap.write(item);
        end
    endtask
endclass

`endif
