import sys
sys.path.append("../py")
from trace_gen import TraceGen
from npa_addr_gen import NPAAddrGen


tg = TraceGen(addr_width_p=39, data_width_p=64)
npa = NPAAddrGen(y_cord_width_p=1, x_cord_width_p=2, epa_addr_width_p=10)

tg.print_header()

npa_addr = npa.get_npa_addr(y=1,x=0,epa_addr=0)
tg.send_store(size=8, addr=(npa_addr | (1 << 38)), data=1234567890)
tg.send_load(size=8, addr=(npa_addr | (1 << 38)), signed=0)

tg.recv_data(data=0)
tg.recv_data(data=1234567890)

npa_addr = npa.get_npa_addr(y=1,x=0,epa_addr=2)
tg.send_store(size=8, addr=(npa_addr | (1 << 38)), data=0x1133557722446688)
tg.send_load(size=1, addr=(npa_addr | (1 << 38))+0, signed=0)
tg.send_load(size=1, addr=(npa_addr | (1 << 38))+1, signed=0)
tg.send_load(size=1, addr=(npa_addr | (1 << 38))+2, signed=0)
tg.send_load(size=1, addr=(npa_addr | (1 << 38))+3, signed=0)
tg.send_load(size=1, addr=(npa_addr | (1 << 38))+4, signed=0)
tg.send_load(size=1, addr=(npa_addr | (1 << 38))+5, signed=0)
tg.send_load(size=1, addr=(npa_addr | (1 << 38))+6, signed=0)
tg.send_load(size=1, addr=(npa_addr | (1 << 38))+7, signed=0)

tg.recv_data(data=0)
tg.recv_data(data=0x88)
tg.recv_data(data=0x66)
tg.recv_data(data=0x44)
tg.recv_data(data=0x22)
tg.recv_data(data=0x77)
tg.recv_data(data=0x55)
tg.recv_data(data=0x33)
tg.recv_data(data=0x11)


npa_addr = npa.get_npa_addr(y=1,x=0,epa_addr=4)
tg.send_store(size=4, addr=(npa_addr | (1 << 38)), data=0xaabbccdd)
tg.send_store(size=4, addr=(npa_addr | (1 << 38))+4, data=0xdeadbeef)

tg.send_load(size=2, addr=(npa_addr | (1 << 38))+0, signed=0)
tg.send_load(size=2, addr=(npa_addr | (1 << 38))+2, signed=0)
tg.send_load(size=2, addr=(npa_addr | (1 << 38))+4, signed=0)
tg.send_load(size=2, addr=(npa_addr | (1 << 38))+6, signed=0)

tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0xccdd)
tg.recv_data(data=0xaabb)
tg.recv_data(data=0xbeef)
tg.recv_data(data=0xdead)

npa_addr = npa.get_npa_addr(y=1,x=1,epa_addr=0)

tg.send_store(size=1, addr=(npa_addr | (1 << 38))+0, data=0xcd)
tg.send_store(size=1, addr=(npa_addr | (1 << 38))+1, data=0xef)
tg.send_store(size=1, addr=(npa_addr | (1 << 38))+2, data=0xf1)
tg.send_store(size=1, addr=(npa_addr | (1 << 38))+3, data=0xe7)
tg.send_store(size=1, addr=(npa_addr | (1 << 38))+4, data=0x84)
tg.send_store(size=1, addr=(npa_addr | (1 << 38))+5, data=0xd2)
tg.send_store(size=1, addr=(npa_addr | (1 << 38))+6, data=0xaa)
tg.send_store(size=1, addr=(npa_addr | (1 << 38))+7, data=0xb9)
tg.send_load(size=8, addr=(npa_addr | (1 << 38))+0, signed=0)

tg.send_load(size=4, addr=(npa_addr | (1 << 38))+0, signed=0)
tg.send_load(size=4, addr=(npa_addr | (1 << 38))+4, signed=0)

tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0xb9aad284e7f1efcd)
tg.recv_data(data=0xe7f1efcd)
tg.recv_data(data=0xb9aad284)


npa_addr = npa.get_npa_addr(y=1,x=1,epa_addr=2)
tg.send_store(size=2, addr=(npa_addr | (1 << 38))+0, data=0xffcd)
tg.send_store(size=2, addr=(npa_addr | (1 << 38))+2, data=0xccef)
tg.send_store(size=2, addr=(npa_addr | (1 << 38))+4, data=0x43f1)
tg.send_store(size=2, addr=(npa_addr | (1 << 38))+6, data=0x87e7)
tg.send_load(size=4, addr=(npa_addr | (1 << 38))+0, signed=0)
tg.send_load(size=4, addr=(npa_addr | (1 << 38))+4, signed=0)


tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0xccefffcd)
tg.recv_data(data=0x87e743f1)

npa_addr = npa.get_npa_addr(y=1,x=2,epa_addr=0)
tg.send_store(size=8, addr=(npa_addr | (1 << 38))+8*0, data=0x1111111111111111)
tg.send_store(size=8, addr=(npa_addr | (1 << 38))+8*1, data=0x2222222222222222)
tg.send_store(size=8, addr=(npa_addr | (1 << 38))+8*2, data=0x3333333333333333)
tg.send_store(size=8, addr=(npa_addr | (1 << 38))+8*3, data=0x4444444444444444)
tg.send_store(size=8, addr=(npa_addr | (1 << 38))+8*4, data=0x5555555555555555)
tg.send_store(size=8, addr=(npa_addr | (1 << 38))+8*5, data=0x6666666666666666)
tg.send_store(size=8, addr=(npa_addr | (1 << 38))+8*6, data=0x7777777777777777)
tg.send_store(size=8, addr=(npa_addr | (1 << 38))+8*7, data=0x8888888888888888)

tg.send_load(size=8, addr=(npa_addr | (0 << 38))+8*0, signed=0)
tg.send_load(size=8, addr=(npa_addr | (0 << 38))+8*1, signed=0)
tg.send_load(size=8, addr=(npa_addr | (0 << 38))+8*2, signed=0)
tg.send_load(size=8, addr=(npa_addr | (0 << 38))+8*3, signed=0)
tg.send_load(size=8, addr=(npa_addr | (0 << 38))+8*4, signed=0)
tg.send_load(size=8, addr=(npa_addr | (0 << 38))+8*5, signed=0)
tg.send_load(size=8, addr=(npa_addr | (0 << 38))+8*6, signed=0)
tg.send_load(size=8, addr=(npa_addr | (0 << 38))+8*7, signed=0)
tg.send_load(size=8, addr=(npa_addr | (0 << 38))+8*0, signed=0)

tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0)
tg.recv_data(data=0)

tg.recv_data(data=0x1111111111111111)
tg.recv_data(data=0x2222222222222222)
tg.recv_data(data=0x3333333333333333)
tg.recv_data(data=0x4444444444444444)
tg.recv_data(data=0x5555555555555555)
tg.recv_data(data=0x6666666666666666)
tg.recv_data(data=0x7777777777777777)
tg.recv_data(data=0x8888888888888888)
tg.recv_data(data=0x1111111111111111)

tg.test_done()
