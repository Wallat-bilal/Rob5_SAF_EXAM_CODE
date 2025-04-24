import socket
import pandas as pd
import numpy as np
import xml.sax


def delete(string, indices):
    z = bytearray(string.encode())
    for i in sorted(indices, key=abs, reverse=True):
        del z[i]
    return z.decode()


class carrierHandler(xml.sax.handler.ContentHandler):
    def __int__(self):
        self.CurrentData = ""
        self.carrier_id = ""
        self.station_number = ""
        self.date = ""
        self.log = open('log.txt', 'a')
    def startElement(self, name, attrs):
        if name == "Info":
            self.log = open('log.txt', 'a')
        elif name == "carrier_id":
            self.CurrentData="Id"
        elif name == "DATE":
            self.CurrentData="date"
        elif name == "station_number":
            self.CurrentData="number"
        else:
            self.CurrentData = ""

    def endElement(self, name):
        if name == "Info":
            self.log.write('Id: ' + str(self.carrier_id) + '\t' +
                           'Station number: ' + str(self.station_number) + '\t' +
                           'Date: ' + str(self.date) + '\n')
            self.log.close()

    def characters(self, content):
        if self.CurrentData == "Id":
            self.carrier_id = content
        if self.CurrentData == "number":
            self.station_number = content
        if self.CurrentData == "date":
            self.date = content



parser = xml.sax.make_parser()
handler = carrierHandler()
parser.setContentHandler(handler)


data = pd.read_csv("procssing_times_table.csv")
a=np.array(data.head(16))
lookup_table = np.zeros([16,16])
for i in range(0, 16):
    lookup_table[i] = str(a[i][0]).split(";")[1:100]
lookup_table.astype(int)



HOST = "172.20.66.30"
PORT = 65432  # Port to listen on (non-privileged ports are > 1023)
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.bind((HOST, PORT))
    s.listen()
    conn, addr = s.accept()
    with conn:
        print(f"Connected by {addr}")
        while True:
            data = conn.recv(1024)
            msg = delete(str(data), [0, 1, -1])
            msg = msg.split('\\x')[0]
            print(msg)
            f = open("msg.xml", "w")
            f.write(msg)
            f.close()
            parser.parse('msg.xml')
            #msg = msg.split(',')[0:3]
            #print(msg)
            if not data:
                break
            conn.sendall(lookup_table[handler.carrier_id][handler.station_number])
