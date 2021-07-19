#!/usr/bin/env python
import easygui
import os

path = easygui.fileopenbox(msg="Select the config file to use", default="~/Downloads/*.config")
if path is not None:
	command = "cd /opt/mitmproxy && sudo ./mitmdump -s redirect_requests.py --set configfile=" + path
	start_mitm = os.system(command)
