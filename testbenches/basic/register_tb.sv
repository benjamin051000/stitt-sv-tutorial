// Greg Stitt
// University of Florida
//
// This example demonstrates several common, but non-ideal, techniques for
// writing testbenches, followed by a simpler approach that separates the
// responsibilities of the testbench into multiple simple processes.
//
// The example also demonstrates a common SystemVerilog "gotcha" with 
// testbenches where undefined inputs or outputs cause error conditions to
// fail counterintuitively, cause errors to go unreported.
//
// IMPORTANT: 
// We will soon see that none of these testbenches are a good way of
// testing a register. They are instead intended to explain basic constructs as 
// we work up to more powerful techniques.

`timescale 1ns / 100 ps


// Module: register_tb1
// Description: A simple, but non-ideal testbench for the register module. 
// This is only demonstrated for explaining common non-ideal strategies. I don't 
// recommend the strategy presented in this module.

module register_tb1 #(
    parameter int NUM_TESTS = 10000,
    parameter int WIDTH = 8
);
    // DUT I/O
    logic clk = 1'b0, rst, en;
    logic [WIDTH-1:0] in, out;

    // Used to help with verification.
    logic [WIDTH-1:0] prev_out;

    // Instantiate the DUT.
    register #(.WIDTH(WIDTH)) DUT (.*);

    // Generate a clock with a 10 ns period
    initial begin : generate_clock
        forever #5 clk <= ~clk;
    end

    // In this testbench, we use a single process to handle all responsibilities.
    // This "monolithic" strategy can sometimes work alright for basic examples, 
    // but will lead to many problems for more complex examples.
    initial begin
        $timeformat(-9, 0, " ns");

        // Reset the register. Following the advice from the race-condition 
        // examples, reset (and all DUT inputs) are asserted with a 
        // non-blocking assignment.
        rst <= 1'b1;
        in  <= '0;
        en  <= 1'b0;
        repeat (5) @(posedge clk);

        // Clear reset on a falling edge. Not necessary (unless using a blocking
        // assignment), but a common practice.
        @(negedge clk);
        rst <= 1'b0;
        @(posedge clk);

        // Generate NUM_TESTS random inputs, once per cycle.
        // This could also be done with repeat(NUM_TESTS) since we aren't using
        // i anywhere, but in many cases you will use i.        
        for (int i = 0; i < NUM_TESTS; i++) begin
            // $urandom is a convenient function for getting a random 
            // 32-bit number. There is also a $random, but I highly recommend
            // against using it. $random is from an older standard, has less 
            // flexible seeding, and generates far worse distributions.
            in <= $urandom;
            en <= $urandom;
            @(posedge clk);

            // We need to save to previous output to verify that the output
            // doesn't change when enable isn't asserted.
            prev_out = out;

            // We need to wait for some amount of time to allow for the 
            // register's output to change. This has an unattractive side effect
            // of shifting all the subsequent inputs by this amount of time.
            // While it still works, I highly recommend against this strategy.
            // I always try to make all my testbenches do everything on rising
            // clock edges. While that isn't necessary, it is an excellent
            // exercise to understand low-level simulation details.
            #1;

            // Verify the outputs.
            if (en && in != out) $error("out = %d instead of %d.", out, in);
            if (!en && out != prev_out) $error("out changed when en wasn't asserted.");
        end

        $display("Tests completed.");
        disable generate_clock;
    end

endmodule  // register_tb1


// Module: register_tb2
// Description: This testbench separates some of the testing responsibilities
// across two blocks to eliminate the input offsets experienced by the previous
// testbench. This is still an overly complex testbench for the register module, 
// which is only demonstrated for explaining commonly attempted strategies. I do
// not recommend the strategy presented in this module.

module register_tb2 #(
    parameter int NUM_TESTS = 10000,
    parameter int WIDTH = 8
);
    logic clk = 1'b0, rst, en;
    logic [WIDTH-1:0] in, out;
    logic [WIDTH-1:0] prev_in, prev_out, prev_en;

    register #(.WIDTH(WIDTH)) DUT (.*);

    initial begin : generate_clock
        forever #5 clk <= ~clk;
    end

    // A process for driving the inputs.
    initial begin : drive_inputs
        $timeformat(-9, 0, " ns");

        rst <= 1'b1;
        in  <= '0;
        en  <= 1'b0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst <= 1'b0;
        @(posedge clk);

        for (int i = 0; i < NUM_TESTS; i++) begin
            in <= $urandom;
            en <= $urandom;
            @(posedge clk);
        end

        $display("Tests completed.");
        disable generate_clock;
    end

    // Here we add a new process for checking the outputs.
    initial begin : check_output
        forever begin
            // Wait for a rising edge and then check the output.
            @(posedge clk);

            // Uncomment to see the value of all signals on each clock edge.
            //
            // The inputs are all the previous values due to the writing process
            // using non-blocking assignments. Use of blocking assignments in the
            // writing process would cause a race condition that could result in
            // non-deterministic behavior.
            //
            // The output has not yet changed at this point because the register
            // uses a non-blocking assignment and this $display reads the value in
            // the same time step. However, even if the circuit wasn't a register and
            // used a blocking assignment, we would again have a race condition
            // because it isn't known whether or not the simulator updates the value
            // of out before it is read here.
            //
            //$display("LOG (time %0t): en = %0b, in = %0d, out = %0d", $time, en, in, out);  

            // Save the previous input and output values so we can test en == 0.
            prev_en  = en;
            prev_in  = in;
            prev_out = out;

            // Give the output time to change. Any amount of time will work as long 
            // as it is less than 1 clock cycle.
            //
            // IMPORTANT: if you find yourself waiting for a small amount of time
            // for an output to change (outside of combinational logic), there is 
            // usually a better way of writing the testbench. Also, ideally your
            // testbench shouldn't care if the output is registered or combinational,
            // so we'll see those better ways in later examples.
            //
            //#1;
            //#0.1;
            @(negedge clk);            

            // If enable was asserted, out should be equal to the previous in.
            if (prev_en && prev_in != out) $error("out = %0d instead of %0d.", out, prev_in);

            // If enable wasn't asserted, the output shouldn't change.
            if (!prev_en && prev_out != out) $error("out changed when en wasn't asserted.");
        end
    end
endmodule  // register_tb2


// Module: register_tb3
// Description: A simpler alternative to the previous testbench that 
// demonstrates a common "gotcha" that prevents errors from being reported.
// This is still not a good testbench for a register. We'll see far simpler
// methods in later examples.

module register_tb3 #(
    parameter int NUM_TESTS = 10000,
    parameter int WIDTH = 8
);
    logic clk = 1'b0, rst, en;
    logic [WIDTH-1:0] in, out;
    logic [WIDTH-1:0] prev_in, prev_out, prev_en;

    register #(.WIDTH(WIDTH)) DUT (.*);

    initial begin : generate_clock
        forever #5 clk <= !clk;
    end

    initial begin : drive_inputs
        $timeformat(-9, 0, " ns");

        rst <= 1'b1;
        in  <= '0;
        en  <= 1'b0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst <= 1'b0;
        @(posedge clk);

        for (int i = 0; i < NUM_TESTS; i++) begin
            in <= $urandom;
            en <= $urandom;

            // Instead of having one process write some signals, and other process
            // write other signals, we can just have one process write and one
            // process read, and make sure to write using non-blocking assignments.
            // Note that the prev_ versions here are intentionally getting the
            // non-updated values by using non-blocking assignments earlier.
            // It is safe to mix blocking and non-blocking assignments in 
            // testbenches, but any blocking assignments must not be to signals
            // read in another process that is synchronized to the same event.
            prev_en <= en;
            prev_in <= in;
            prev_out <= out;
            @(posedge clk);
        end

        $display("Tests completed.");
        disable generate_clock;
    end

    // Since we are tracking the previous values, we can just directly compare
    // the output to those values. This is a cleaner strategy than waiting
    // for the output to change. Basically, instead of preserving values, waiting
    // for output to change, and then comparing, we just save previous values
    // and compare with the current output value. This way, we are always
    // checking outputs on the rising edge.
    //
    // Again, if you ever find yourself having to check a value shortly after a 
    // clock edge to get the right value (or to avoid a race condition), there is
    // almost certainly an easier way to do the testbench.
    initial begin : check_output
        forever begin
            @(posedge clk);            

            // IMPORTANT: The following validation code has a very common
            // "gotcha." Note that during reset, prev_out, prev_in, and prev_en 
            // are all 'X. However, no error is printed.
            //
            // This confuses many people because clearly en is 1'b0 initially,
            // and prev_out (X) != out (0). So, the second if statement should be
            // causing an error. Why don't we see an error message?
            //
            // The answer has to do with how Xs are treated by various 
            // operators. For most operators, an X input will result in an X
            // output, which will be treated as false in an if statement. 
            // So, any time an X occurs in a != or == comparison, the 
            // result is always X, which is treated as false. This is confusing
            // because X != 0 results in X, which causes the if condition to
            // be false, when we would normally expect it to be true. You'll 
            // see similar confusing outcomes with other operators too. e.g.,
            // both if (1'bX) and if (!1'bX) evaluate to false, which can be
            // quite counterintuive initially.
            //            
            // So, what's happening here is that because prev_en is X initially,
            // both if statements are guaranteed to evalute to false, causing
            // no errors to be printed. Even if prev_en was defined (e.g., 0), 
            // prev_out != out would still evaluate to false because 
            // prev_out is X, resulting in the != being X.
            //
            // Unfortunately, these types of bugs are quite common and result in
            // mistaken assumptions about correct execution, when in reality 
            // the output or input was just undefined.
            //
            // To avoid this problem, SystemVerilog includes different comparison
            // operators: !== and ===. These operators do an explicit comparison
            // of the values, treating X like any other possible value. So,
            // 1'b0 !== 1b'X would return true, which is what we originally 
            // intended.

            if (prev_en && prev_in != out) $error("out = %d instead of %d.", out, prev_in);

            // A better alternative the previous line. No errors are printed by
            // this, but only because the prev_en === 1'b1 returns false during
            // reset.
            //if (prev_en === 1'b1 && prev_in !== out) $error("out = %0d instead of %0d.", out, prev_in);
            
            // This is the problematic line that misses actual errors.
            if (!prev_en && prev_out != out) $error("out = %d instead of %d.", out, prev_in);

            // This alternative catches the error that the previous line misses.
            // Uncomment to see the error.
            //if (prev_en !== 1'b1 && prev_out !== out) $error("out = %0d instead of %0d.", out, prev_in);

            // NOTE: === and !== are not synthesizable. Only use them in testbenches.
        end
    end
endmodule  // register_tb3


// Module: register_tb4
// Description: A simpler alternative to the previous testbenches. This version
// uses a common strategy of separating the responsibilities of the testbench
// into separate processes, which results in each process being much simpler.
// In addition, this version now also tests outputs during reset.
//
// If I had to create a testbench without using any of the more advanced 
// constructs we haven't covered yet, I would likely use this strategy.

module register_tb4 #(
    parameter int NUM_TESTS = 10000,
    parameter int WIDTH = 8
);
    logic clk = 1'b0, rst, en;
    logic [WIDTH-1:0] in, out;
    logic [WIDTH-1:0] expected = '0;

    register #(.WIDTH(WIDTH)) DUT (.*);

    initial begin : generate_clock
        forever #5 clk <= !clk;
    end

    // This example separates responsibilities into different blocks. This block
    // is now solely provides input stimuli to the DUT.
    initial begin : provide_stimulus
        rst <= 1'b1;
        in  <= '0;
        en  <= 1'b0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst <= 1'b0;
        repeat (2) @(posedge clk);

        for (int i = 0; i < NUM_TESTS; i++) begin
            in <= $urandom;
            en <= $urandom;
            @(posedge clk);
        end

        $display("Tests completed.");
        disable generate_clock;
    end

    // To simplify the logic of the previous testbenches, we have a separate
    // block whose sole responsibility is to monitor for ouputs and then 
    // determine the correct/expected output each cycle. This code works because
    // on a rising clock edge, neither the input or output has changed values
    // yet. Because the output hasn't changed, we can simply read from out to
    // get the previous output in the case where enable isn't asserted.
    initial begin : monitor        
        forever begin
            @(posedge clk);
            expected <= rst ? '0 : en ? in : out;
        end
    end

    // With the previous process being responsible for determining the expected
    // output, now we can simply compare the actual and expected in this block
    // on every clock edge. Note that expected had to be initialize to 0 to
    // prevent the first comparison from using an undefined value. 0 was chosen
    // to match the reset of the output.
    initial begin : check_outputs
        forever begin
            @(posedge clk);
            // Note that we are using !== here to catch any undefined values.
            if (expected !== out) $error("Expected=%0h, Actual=%0h", expected, out);
        end
    end
endmodule
