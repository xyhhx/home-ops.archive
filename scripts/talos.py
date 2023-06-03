import argparse
import json
import subprocess
from dotenv import load_dotenv
from os import getenv
from pathlib import Path
from time import sleep


load_dotenv()
talosconfig = Path(getenv('TALOSCONFIG'))
talos_secrets = Path('talos/secrets.yaml')

parser = argparse.ArgumentParser()
parser.add_argument('action')
parser.add_argument('--show-commands', required=False,
                    action=argparse.BooleanOptionalAction)
parser.add_argument('--type', required=False)
parser.add_argument('--dry-run', required=False,
                    action=argparse.BooleanOptionalAction)
args = parser.parse_args()


def run_command(command):
    if (args.show_commands != False):
        print(command)
    if not args.dry_run:
        result = subprocess.run(command.split(' '), capture_output=True)
        return result
    return


def get_leases():
    result = run_command('poetry run opnsense leases')
    data = json.loads(result.stdout.decode('utf-8'))

    return data


def show_node_ips(node_type):
    data = get_leases()

    for value in data[node_type]:
        print(value)


def check_secrets_exist():
    if talos_secrets.is_file() is False:
        print('No talos secrets. Please generate them')
        exit(0)


def gen_talos_conf(ipaddr):

    if talosconfig.is_file():
        print('%a exists, not generating a new one' % talosconfig)
        return

    command = "talosctl gen config %s https://%s:6443 \
--with-docs=false \
--with-examples=false \
--with-secrets talos/secrets.yaml \
--config-patch @generated/all.yaml \
--config-patch-control-plane @generated/controlplane.yaml \
--config-patch-control-plane @generated/cilium.yaml \
--config-patch-worker @generated/worker.yaml \
--output %s" % (
        getenv('TALOS_CLUSTER_NAME'), ipaddr, talosconfig.parent)
    run_command(command)


def apply_config(ipaddr, conf_file):
    command = "talosctl apply-config --insecure --nodes %s --file %s/%s.yaml" % (
        ipaddr, talosconfig.parent, conf_file)
    return run_command(command)


def retry_command(command, max_tries=3, wait=30):
    run = 0
    print("Gonna try running %s times, and will wait %s seconds between tries" % (
        max_tries, wait))
    while run < max_tries:
        print("Attempt %s" % (run + 1))
        try:
            run_command(command)
            return True
        except:
            print("Waiting %s seconds..." % (wait))
            sleep(wait)
        finally:
            run += 1

    raise Exception()


def main():
    check_secrets_exist()

    if args.action == 'ips':
        show_node_ips(args.type)
        exit()

    # config_generated = False
    data = get_leases()

    if args.action == 'gen':
        # if config_generated == False:
        gen_talos_conf(data['control_plane'][0])
        # config_generated = True
        run_command('talosctl --talosconfig %s/talosconfig config endpoint %s' %
                    (talosconfig.parent, ' '.join([ip for ip in data['control_plane']])))
        run_command('talosctl --talosconfig %s/talosconfig config node %s' %
                    (talosconfig.parent, ' '.join([ip for ip in data['control_plane']])))
        print('Your configs have been generated, and are available in %s/' %
              talosconfig.parent)
        exit()

    if args.action == 'apply':
        for ip in data['control_plane']:
            apply_config(ip, 'controlplane')

        for ip in data['workers']:
            apply_config(ip, 'worker')

        print("Configs applied. You may want to wait a few moments before continuing.")
        exit()

    if args.action == 'bootstrap':
        commands = [
            'talosctl -n %s bootstrap' % (data['control_plane'][0]),
            'talosctl -n %s kubeconfig .' % (data['control_plane'][0]),
        ]

        for command in commands:
            print(command)
            if not args.dry_run:
                try:
                    retry_command(command)
                except Exception:
                    print("The following command could not complete:\n%s" % command)
                    exit(1)
        print("Configs applied. You may want to wait a few moments before continuing.")
        exit()


if __name__ == "__main__":
    main()
