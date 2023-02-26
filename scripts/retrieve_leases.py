import requests
import json
import subprocess
import re
from os import getenv
from bs4 import BeautifulSoup
from dotenv import load_dotenv
from requests.packages.urllib3.exceptions import InsecureRequestWarning


requests.packages.urllib3.disable_warnings(InsecureRequestWarning)


def get_macs():
    result = subprocess.run(
        ["terraform", "-chdir=terraform", "output", "-json"], capture_output=True)
    data = json.loads(result.stdout.decode("UTF-8"))
    macs = {
        "control_plane": [item[1][0] for item in data['control_plane_macs']['value'].items()],
        "workers": [item[1][0] for item in data['worker_macs']['value'].items()]
    }

    return macs


def get_csrf_token(session):
    response = session.get(getenv('OPNSENSE_URL'), verify=False)
    regex = r"X-CSRFToken\", \"(\w+)"
    matches = re.finditer(regex, response.text, re.MULTILINE)
    csrf_token = next(matches).group(1)

    return csrf_token


def get_dhcp_page(session, csrf_token):
    endpoint = 'status_dhcp_leases.php?order=&all=1'
    data = {
        'login': 'Login',
        'usernamefld': getenv('OPNSENSE_USER'),
        'passwordfld': getenv('OPNSENSE_PASS'),
    }

    headers = {
        'X-CSRFToken': csrf_token
    }

    session.headers.update(headers)
    response = session.post('%s/%s' %
                            (getenv('OPNSENSE_URL'), endpoint), data)

    return response


def parse_leases(response):
    soup = BeautifulSoup(response.text, features="html.parser")
    rows = [row for row in soup.find_all(
        'tr') if row.text.__contains__('NICE')]
    regex = r"([0-9\.]+).* ([\w:]{17})"

    leases = {}
    for row in rows:
        matches = re.finditer(regex, row.text, re.MULTILINE | re.DOTALL)
        for matchNum, match in enumerate(matches, start=1):
            leases[match.group(2)] = match.group(1)

    return leases


def main():
    load_dotenv()
    s = requests.Session()
    csrf_token = get_csrf_token(s)
    response = get_dhcp_page(s, csrf_token)
    all_leases = parse_leases(response)
    talos_macs = get_macs()

    print('%s' % json.dumps(talos_macs))


main()
