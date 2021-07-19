"""
Script to make the run of capture traffic easier
"""
import psutil
import os
import subprocess
import re
import time
import socket


def check_is_digit(input_str):
    if input_str.strip().isdigit():
        if int(input_str) == 1 or int(input_str) == 2:
            return True
    return False
    
def get_file_name(result):
    rx = re.compile('^File: (\S+)$', re.MULTILINE)
    m = rx.search(result)
    if m:
        file_name = m.group(1)
        return file_name
    return ""

def wait_for_port(port, host='localhost', timeout=120.0):
    """Wait until a port starts accepting TCP connections.
    Args:
        port (int): Port number.
        host (str): Host address on which the port should exist.
        timeout (float): In seconds. How long to wait before raising errors.
    Raises:
        TimeoutError: The port isn't accepting connection after time specified in `timeout`.
    """
    start_time = time.perf_counter()
    while True:
        try:
            with socket.create_connection((host, port), timeout=timeout):
                break
        except OSError as ex:
            time.sleep(0.01)
            if time.perf_counter() - start_time >= timeout:
                raise TimeoutError('Waited too long for the port {} on host {} to start accepting '
                                   'connections.'.format(port, host)) from ex
  
def modify_conf_file(filename):
    f = open('/etc/logstash/conf.d/tshark.conf','r')
    filedata = f.readlines()
    f.close()
    
    file_name=""
    for i in range(0, len(filedata)):
        if "index =>" in filedata[i]:
           filedata[i] = "    index => \""+ filename +"\"\n"

    f = open('/etc/logstash/conf.d/tshark.conf','w')
    f.writelines(filedata)
    f.close()


# Get the total RAM minus the used RAM to see if we can run the live method
ramAvailable = round(psutil.virtual_memory()[1] / 1000000000, 2)
print("RAM Available in GB", ramAvailable)
if ramAvailable < 8.00:
    print("It will be better for you to choose the second method because the first one uses a lot of RAM and this "
          "could cause your PC to slow-down")
print("====================================")
print("Choose the method you want to use")
print("[1] Live Method consumes a lot of RAM")
print("[2] Capture mode can create a file with 1GB of size be careful with the disk space")

while True:
    num = input("Enter our choice : ")
    if check_is_digit(num):
        num = int(num)
        break
        
filename = input("Enter the name of the capture : ")

modify_conf_file(filename)

if os.system('systemctl is-active --quiet elasticsearch') == 0:
   print("ElasticSearch is already running")
else:
   print("Starting Elasticsearch...")
   os.system('service elasticsearch start')
   print("Elasticsearch started")
print("Starting Logstash...")
os.system('service logstash start')
wait_for_port(17570)
print("Logstash started")

print("Capture has started")
print("Press Ctrl-C to stop the captures")

if num == 1:
    print("The capture will be available in elasticsearch with the name", filename)
    os.system('sudo tshark -i ens34 -f"tcp port 8080" -T ek -Y http | netcat localhost 17570')
else:
    proc = subprocess.Popen('dumpcap -i ens34 -f"tcp port 8080" -a filesize:1000000', shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
       for line in proc.stderr:
           if b'File: ' in line:    
            filename_pcap = get_file_name(line.decode("utf-8"))
            print("Name of the pcap file :", filename_pcap)
    except KeyboardInterrupt:
       proc.kill()
       print()

if num == 2:
    command = 'sudo tshark -r ' + filename_pcap + ' -T ek -Y http | netcat localhost 17570 -w10'
    print(command)
    os.system(command)
    print("The capture is now available in elasticsearch with the name", filename)

print("Stoping Logstash...")
os.system('service logstash stop')
print("Logstash stopped")
