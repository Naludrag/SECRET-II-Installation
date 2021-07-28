"""
This code redirect flows destined to blacklisted domains.
"""
import typing

from mitmproxy import http
from mitmproxy import exceptions
from mitmproxy import ctx


class ConfigFile:
    def load(self, loader):
        loader.add_option(
            name="configfile",
            typespec=typing.Optional[str],
            default=None,
            help="Add config file for websites blocking",
        )

    def parseFile(self):
        file = ctx.options.configfile
        f = open(file, "r")
        self.sites = []
        for line in f.readlines():
            line = line.strip()
            if line == "white" or line == "black":
                self.choice = line
            else:
                self.sites.append(line)
        print("Sites being blocked :", self.sites)
        print("Policy              :", self.choice)
        return True

    def configure(self, updates):
        if "configfile" in updates:
            if ctx.options.configfile is not None and self.parseFile() != True:
                raise exceptions.OptionsError("Problem with config file given")

    def request(self, flow):
        # Fail with 403
        for domain in self.sites:
            if flow.request.pretty_host.endswith(domain):
                flow.response = http.HTTPResponse.make(403, b"<h2>You are not allowed here :)</h2>")


addons = [
    ConfigFile()
]