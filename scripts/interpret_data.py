import sys
import struct 
import matplotlib.pyplot as plt
import matplotlib

if len(sys.argv) != 2:
    print("interpret_data.py filename")
    sys.exit(-1);

filename = sys.argv[1]

res = []

with open(filename, "rb") as file:
    while(word:=file.read(2)):
        if word == b"\xff\xff":break
        unpacked = struct.unpack("H", word)
        res.append(unpacked[0])

res = res[:len(res) // 8]

plt.plot([i for i in range(len(res))], res, "-bo")
plt.show()

