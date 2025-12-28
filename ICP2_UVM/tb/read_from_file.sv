    // ======================================================
    // TB write preparation task:
    // - Reads decimal values from ifm.h into ifm_data[0:2351]
    // - Reads decimal values from w.h into kernel_data[0:26]
    // - Ignores lines that do not contain valid integers
    // ======================================================

    //TODO:
    /*actually it makes no difference if read_from_file is compiled or not
    
    Because read_from_file.sv is not a design unit — it's just a plain task definition. As long as it is included into a module (like tb_apb), it becomes part of that module's compilation context*/

    //TODO:
    /*Previously, load_arrays() worked without arguments because:

    All the arrays (ifm_data, kernel_data, etc.) were declared in the same module (your testbench).

    Since tasks in SystemVerilog can access variables in their parent scope, the task didn’t need to take parameters.

    That works only if the task is defined inside the same module (not included from another file/module).*/

    task load_arrays(
        output int ifm_data0[0:2351],
        output int ifm_data1[0:2351],
        output int ifm_data2[0:2351],

        output int kernel_data0[0:26],
        output int kernel_data1[0:26],
        output int kernel_data2[0:26],

        output int expected_output0[0:783],
        output int expected_output1[0:783],
        output int expected_output2[0:783]
    );

        int fd_ifm0, fd_ifm1, fd_ifm2;
        int fd_ker0, fd_ker1, fd_ker2;
        int fd_ofm0, fd_ofm1, fd_ofm2;
        int value, i;
        string line;
        // ----------------
        // Data 0
        // ----------------
        fd_ifm0 = $fopen("stimuli/ifm0.h", "r");
        if (!fd_ifm0) $fatal("Cannot open stimuli/ifm0.h");
        
        i = 0;
        while (!$feof(fd_ifm0) && i < 2352) begin
            // Read one line
            void'($fgets(line, fd_ifm0));              
            // Parse integer
            if ($sscanf(line, "%d", value) == 1) begin     
            // Store in array
                ifm_data0[i++] = value;               
            end
        end

        $fclose(fd_ifm0);  // Close IFM file

        // ----------------
        //  Data 1
        // ----------------
        fd_ifm1 = $fopen("stimuli/ifm1.h", "r");
        if (!fd_ifm1) $fatal("Cannot open stimuli/ifm1.h");

        i = 0;
        while (!$feof(fd_ifm1) && i < 2352) begin
            void'($fgets(line, fd_ifm1));
            if ($sscanf(line, "%d", value) == 1)
                ifm_data1[i++] = value;
        end
        $fclose(fd_ifm1);

        // ----------------
        // Data 2
        // ----------------
        fd_ifm2 = $fopen("stimuli/ifm2.h", "r");
        if (!fd_ifm2) $fatal("Cannot open stimuli/ifm2.h");

        i = 0;
        while (!$feof(fd_ifm2) && i < 2352) begin
            void'($fgets(line, fd_ifm2));
            if ($sscanf(line, "%d", value) == 1)
                ifm_data2[i++] = value;
        end
        $fclose(fd_ifm2);

        // ----------------
        // Kernel 0
        // ----------------
        fd_ker0 = $fopen("stimuli/w0.h", "r");
        if (!fd_ker0) $fatal("Cannot open stimuli/w0.h");

        i = 0;
        while (!$feof(fd_ker0) && i < 27) begin
            void'($fgets(line, fd_ker0));
            if ($sscanf(line, "%d", value) == 1)
                kernel_data0[i++] = value;
        end
        $fclose(fd_ker0);

        // ----------------
        // Kernel 1
        // ----------------
        fd_ker1 = $fopen("stimuli/w1.h", "r");
        if (!fd_ker1) $fatal("Cannot open stimuli/w1.h");

        i = 0;
        while (!$feof(fd_ker1) && i < 27) begin
            void'($fgets(line, fd_ker1));
            if ($sscanf(line, "%d", value) == 1)
                kernel_data1[i++] = value;
        end
        $fclose(fd_ker1);

        // ----------------
        // Kernel 2
        // ----------------
        fd_ker2 = $fopen("stimuli/w2.h", "r");
        if (!fd_ker2) $fatal("Cannot open stimuli/w2.h");

        i = 0;
        while (!$feof(fd_ker2) && i < 27) begin
            void'($fgets(line, fd_ker2));
            if ($sscanf(line, "%d", value) == 1)
                kernel_data2[i++] = value;
        end
        $fclose(fd_ker2);
 
        // ----------------
        // OFM 0
        // ----------------
        fd_ofm0 = $fopen("stimuli/ofm0.h", "r");
        if (!fd_ofm0) $fatal("Cannot open stimuli/ofm0.h");

        i = 0;
        while (!$feof(fd_ofm0) && i < 784) begin
            void'($fgets(line, fd_ofm0));
            if ($sscanf(line, "%d", value) == 1)
                expected_output0[i++] = value;
        end
        $fclose(fd_ofm0);

        // ----------------
        // OFM 1
        // ----------------
        fd_ofm1 = $fopen("stimuli/ofm1.h", "r");
        if (!fd_ofm1) $fatal("Cannot open stimuli/ofm1.h");

        i = 0;
        while (!$feof(fd_ofm1) && i < 784) begin
            void'($fgets(line, fd_ofm1));
            if ($sscanf(line, "%d", value) == 1)
                expected_output1[i++] = value;
        end
        $fclose(fd_ofm1);

        // ----------------
        // OFM 2
        // ----------------
        fd_ofm2 = $fopen("stimuli/ofm2.h", "r");
        if (!fd_ofm2) $fatal("Cannot open stimuli/ofm2.h");

        i = 0;
        while (!$feof(fd_ofm2) && i < 784) begin
            void'($fgets(line, fd_ofm2));
            if ($sscanf(line, "%d", value) == 1)
                expected_output2[i++] = value;
        end
        $fclose(fd_ofm2);

    endtask