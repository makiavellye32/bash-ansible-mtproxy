#!/bin/bash
rm -f /etc/ansible/hosts
cp /etc/ansible/hosts_clean /etc/ansible/hosts
rm -rf /etc/ansible/group_vars
