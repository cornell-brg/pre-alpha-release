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
sync_top: bge r0 r1 finish_init
pushq lceCmd SYNC r0
popq lceResp r4
bne r3 r4 error
inc r0
bi sync_top

# set default value for mshr.next_coh_state
finish_init: movis COH_E cohSt

# Wait for LCE Requests
# Try to fast-path the request
ready: clm
poph lceReq
rdp req
# pending or uncached should be handled without issuing a speculative access
bfor pf ucf handle_pf_ucf
# send speculative memory access, also sets speculative flag
pushq memCmd spec
# dequeue the request
popq lceReq
# read the directory and process
rdw req req req
gad
# handle slowly if invalidate, replacement, transfer, upgrade
bfor if rf tf uf handle_req
# write, cached (but no invalidations), or non-exlcusive read
bfor rqf cf nerf modify_state

# complete fast path access
# uses the speculative memory access
fast_path_complete: wde req req lru req nextCohSt
# clear spec bit
specq unset
# request handling complete
bi ready

# write request sets state to M, but otherwise can complete fast-path
modify_state: bfz rqf set_shared
wde req req lru req COH_M
specq fwd_mod COH_M
bi ready

# nerf or others with block cached (and no invalidations) sets state to S, but otherwise fast-path
set_shared: wde req req lru req COH_S
specq fwd_mod COH_S
bi ready

# handle pending flag set or uncached access
# pending jumps back to ready, waits for memory response to return and clear flag
handle_pf_ucf: bf pf ready
# Uncached Request Routine
# Note: hardware detects if it is load/store for the memCmd based on rqf
# but, it might be better to change HW to require a command type and addr sel in ucode for every memCmd
uncached_req: popq lceReq
pushq memCmd
bi ready

# Handle request that wasn't easily fast-pathed (if, rf, tf, uf)

# Next Coherence State Routine
# write request means set to M, else check non-exclusive request
handle_req: bf rqf next_coh_set_m
# non-exclusive request (read-only) or blocked cached somewhere, set to S
bfor cf nerf next_coh_set_s
# invalidations not required, thus block not cache, set to E
next_coh_set_e: movis E nextCohSt
bi inv_check
next_coh_set_s: movis S nextCohSt
bi inv_check
next_coh_set_m: movis M nextCohSt
# fall through to inv_check

# Invalidation Check
inv_check: bfz if upgrade_check

# Invalidation Routine
invalidate: inv

# Upgrade Check Routine
upgrade_check: bfz uf set_entry

# Upgrade Routine
upgrade: wds req req req nextCohSt
pushq lceCmd STW req req req
# squash speculative memory access
specq squash
bi ready

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
# current lceResp is known to be writeback response
popq lceResp r0
# replacement done, explicitly set replacement flag to 0
complete_replacement: sfz rf

# Transfer Check
transfer_check: bfz tf read_l2

# Transfer routine - other cache has block in E/M
transfer: pushq lceCmd TR tr req tr
pushq lceCmd WB tr req tr
# squash speculative memory access
specq squash
# wait for transfer WB response
transfer_poph: poph lceResp r0
beqi r0 COH_ACK transfer_poph
bf nwbf complete_transfer
pushq memCmd MEM_CMD_WB req
# current lceResp is known to be writeback response
complete_transfer: popq lceResp r0
bi ready

# Read Line from L2 Routine
# memory access was already issued speculatively, so resolve the speculation
read_l2: bf rqf resolve_fwd_mod_m
bfor cf nerf resolve_fwd_mod_s
# resolve with COH_E, which was state request was issued with
resolve_e: specq unset
bi ready
resolve_fwd_mod_m: specq fwd_mod COH_M
bi ready
resolve_fwd_mod_s: specq fwd_mod COH_S
bi ready

error: stall
