import json
import subprocess
from dotenv import load_dotenv
from os import getenv

out_dir = ".talosconf"
dry_run = False


def gen_talos_conf(ipaddr):
    command = 'talosctl gen config %s https://%s:6443 --output %s' % (
        getenv('TALOS_CLUSTER_NAME'), ipaddr, out_dir)
    print(command)
    if not dry_run:
        result = subprocess.run(command.split(' '), capture_output=True)


def apply_config(ipaddr, conf_file):
    command = "talosctl apply-config --insecure --nodes %s --file %s/%s.yaml" % (
        ipaddr, out_dir, conf_file)
    print(command)
    if not dry_run:
        result = subprocess.run(command.split(' '), capture_output=True)


def main():
    load_dotenv()
    config_generated = False
    result = subprocess.run(
        ["poetry", "run", "python", "./scripts/retrieve-leases.py"], capture_output=True)
    data = json.loads(result.stdout.decode('utf-8'))

    for ipaddr in data['control_plane']:
        if config_generated == False:
            gen_talos_conf(ipaddr)
            config_generated = True
        apply_config(ipaddr, 'controlplane')

    for ipaddr in data['workers']:
        apply_config(ipaddr, 'worker')

    print('waiting 30 seconds...')
    sleep(30000)
    print('continuing')

    commands = [
        'talosctl --talosconfig %s/talosconfig config endpoint %s' %
        (out_dir, data['control_plane'][0]),
        'talosctl --talosconfig %s/talosconfig config node %s' %
        (out_dir, data['control_plane'][0]),
        'talosctl --talosconfig %s/talosconfig bootstrap' % out_dir,
        'talosctl --talosconfig %s/talosconfig kubeconfig .' % out_dir,
    ]

    for cmd in commands:
        print(cmd)
        if not dry_run:
            subprocess.run(cmd.split(' '))


main()
