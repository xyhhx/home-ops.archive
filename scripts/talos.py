import argparse
import json
import subprocess
from dotenv import load_dotenv
from os import getenv
from time import sleep

out_dir = ".talosconf"
dry_run = False


def run_command(command):
    print(command)
    if not dry_run:
        result = subprocess.run(command.split(' '), capture_output=True)
    return result


def get_leases():
    result = run_command(
        'poetry run python ./scripts/retrieve-leases.py')
    data = json.loads(result.stdout.decode('utf-8'))

    return data


def gen_talos_conf(ipaddr):
    command = 'talosctl gen config %s https://%s:6443 --output %s' % (
        getenv('TALOS_CLUSTER_NAME'), ipaddr, out_dir)
    return run_command(command)


def apply_config(ipaddr, conf_file):
    command = "talosctl apply-config --insecure --nodes %s --file %s/%s.yaml" % (
        ipaddr, out_dir, conf_file)
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
    load_dotenv()

    parser = argparse.ArgumentParser(prog="Talos helper script")
    parser.add_argument("--config", action=argparse.BooleanOptionalAction)
    parser.add_argument("--bootstrap", action=argparse.BooleanOptionalAction)
    args = parser.parse_args()

    config_generated = False
    data = get_leases()

    if args.config is not False:
        for ipaddr in data['control_plane']:
            if config_generated == False:
                gen_talos_conf(ipaddr)
                config_generated = True
            apply_config(ipaddr, 'controlplane')

        for ipaddr in data['workers']:
            apply_config(ipaddr, 'worker')
        print("Configs set. You may want to wait a few moments before continuing.")

    if args.bootstrap is not False:
        commands = [
            'talosctl --talosconfig %s/talosconfig config endpoint %s' %
            (out_dir, data['control_plane'][0]),
            'talosctl --talosconfig %s/talosconfig config node %s' %
            (out_dir, data['control_plane'][0]),
            'talosctl --talosconfig %s/talosconfig bootstrap' % out_dir,
            'talosctl --talosconfig %s/talosconfig kubeconfig .' % out_dir,
        ]

        for command in commands:
            print(command)
            if not dry_run:
                try:
                    retry_command(command)
                except Exception:
                    print("The following command could not complete:\n%s" % command)
                    exit(1)

        print("You may want to run the following:\nexport TALOSCONFIG=%s/talosconfig\nexport KUBECONFIG=kubeconfig" % (out_dir))


main()
