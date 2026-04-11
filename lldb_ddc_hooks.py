import lldb

read_buf_ptr = None

def read_entry(frame, bp_loc, dict):
    """Called when IOAVServiceReadI2C is entered"""
    global read_buf_ptr
    x0 = frame.FindRegister("x0").GetValueAsUnsigned()
    x1 = frame.FindRegister("x1").GetValueAsUnsigned()
    x2 = frame.FindRegister("x2").GetValueAsUnsigned()
    x3 = frame.FindRegister("x3").GetValueAsUnsigned()
    x4 = frame.FindRegister("x4").GetValueAsUnsigned()
    read_buf_ptr = x3
    print(f"[HOOK] IOAVServiceReadI2C ENTRY: service=0x{x0:x}, chipAddr=0x{x1:x}, offset=0x{x2:x}, buf=0x{x3:x}, size={x4}")
    return False  # Don't stop

def read_exit(frame, bp_loc, dict):
    """Called when IOAVServiceReadI2C returns"""
    global read_buf_ptr
    x0 = frame.FindRegister("x0").GetValueAsUnsigned()
    print(f"[HOOK] IOAVServiceReadI2C RETURN: ret=0x{x0:x}")
    if read_buf_ptr:
        process = frame.GetThread().GetProcess()
        error = lldb.SBError()
        data = process.ReadMemory(read_buf_ptr, 12, error)
        if error.Success():
            hexdata = ' '.join(f'{b:02x}' for b in data)
            print(f"[HOOK] Buffer: {hexdata}")
        else:
            print(f"[HOOK] Buffer read error: {error}")
    return False  # Don't stop

def write_entry(frame, bp_loc, dict):
    """Called when IOAVServiceWriteI2C is entered"""
    x0 = frame.FindRegister("x0").GetValueAsUnsigned()
    x1 = frame.FindRegister("x1").GetValueAsUnsigned()
    x2 = frame.FindRegister("x2").GetValueAsUnsigned()
    x3 = frame.FindRegister("x3").GetValueAsUnsigned()
    x4 = frame.FindRegister("x4").GetValueAsUnsigned()
    process = frame.GetThread().GetProcess()
    error = lldb.SBError()
    data = process.ReadMemory(x3, x4, error)
    if error.Success():
        hexdata = ' '.join(f'{b:02x}' for b in data)
    else:
        hexdata = "???"
    print(f"[HOOK] IOAVServiceWriteI2C: service=0x{x0:x}, chipAddr=0x{x1:x}, offset=0x{x2:x}, data=[{hexdata}], size={x4}")
    return False  # Don't stop

def __lldb_init_module(debugger, internal_dict):
    # Set breakpoints
    debugger.HandleCommand('breakpoint set -n IOAVServiceWriteI2C')
    debugger.HandleCommand('breakpoint set -n IOAVServiceReadI2C')
    # Note: commands for breakpoints will be set up separately
    print("[HOOK] DDC hooks loaded")
