"""
Script to start mitmproxy with the right configuration
"""
import easygui
import os

# Show the file explorer and only accept .config files
path = easygui.fileopenbox(msg="Select the config file to use", default="~/Downloads/*.config")
# If config file is passed run mitmproxy with the configuration
if path is not None:
	command = "cd /opt/mitmproxy && sudo ./mitmdump -s redirect_requests.py --set configfile=" + path
	start_mitm = os.system(command)
