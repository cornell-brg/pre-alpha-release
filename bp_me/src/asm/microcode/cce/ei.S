# This microcode uses EI protocol with LCE transfers enabled
# The CCE process requests sequentially, and waits for all memory responses

#include "microcode.h"

# invalidate every entry in directory
rst_wg_init: movsg numWG r0
rst_wg_check: bz r0 sync_init
dec r0
rst_lce_init: movsg numLCE r1
rst_lce_check: bz r1 rst_wg_check
dec r1
rst_way_init: movsg lceAssoc r2
rst_way_check: bz r2 rst_lce_check
dec r2
wde r0 r1 r2 0 I
bi rst_way_check

# send sync messages
# r0 counts up from 0 number of sync messages sent
# r1 holds constant numLCE
# r3 stores the constant SYNC_ACK to check response ack type against
# The CCE waits for sync ack after each sync command. This avoids additional buffering being
# required in the CCE, at a small "performance" cost during startup
sync_init: movi 0 r0
movsg numLCE r1
movi SYNC_ACK r3
sync_top: bge r0 r1 ready
pushq lceCmd SYNC r0
popq lceResp r4
bne r3 r4 error
inc r0
bi sync_top

# Ready Routine
ready: wfq lceReq

# LCE Request Routine
lce_req: clm
poph lceReq
bf ucf uncached_req
rdp req
bf pf ready
popq lceReq
rdw req req req
gad
# fall through

# Next Coherence State Routine
next_coh_state: movis E nextCohSt

# Invalidation Check
inv_check: bfz if upgrade_check

# Invalidation Routine
invalidate: inv

# Upgrade Check Routine
upgrade_check: bfz uf set_entry

# Upgrade Routine
upgrade: bi error

# write directory entry before memory messages may occur
# next_coh_state is not saved/restored across memory access
set_entry: wde req req lru req nextCohSt

# Replacement Check Routine
replace_check: bfz rf transfer_check

# Replacement Routine
replace: pushq lceCmd WB req lru lru
# wait for writeback response
replacement_poph: poph lceResp r0
beqi r0 COH_ACK replacement_poph
bf nwbf complete_replacement
pushq memCmd MEM_CMD_WB lru
popq lceResp r0
# replacement done, explicitly set replacement flag to 0
complete_replacement: sfz rf

# Transfer Check
transfer_check: bfz tf read_l2

# Transfer routine - other cache has block in E/M
transfer: pushq lceCmd TR tr req tr
pushq lceCmd WB tr req tr
# wait for transfer WB response
transfer_poph: poph lceResp r0
beqi r0 COH_ACK transfer_poph
bf nwbf complete_transfer
pushq memCmd MEM_CMD_WB req
complete_transfer: popq lceResp r0
bi ready

# Read Line from L2 Routine
# TODO: move memory request earlier to hide some latency
read_l2: pushq memCmd
bi ready

# Uncached Request Routine
# TODO: collapse, hardware detects if it is load/store for the memCmd based on rqf
# but, it might be better to change HW to require a command type and addr sel in ucode for every memCmd
uncached_req: popq lceReq
bf rqf uncached_store
pushq memCmd
bi ready
uncached_store: pushq memCmd
bi ready

error: stall
