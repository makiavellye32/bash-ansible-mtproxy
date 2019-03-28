#!/bin/bash
echo 'Скрипт подготавливает удаленный сервер к установке прокси и, собственно, делает это' | cowsay -f dragon
echo 'Генерация ключа шифрования для доступа без пароля'

# Добавляем секцию хостов ансибла в конфиг
sed -i "$ a \[mtproto]" /etc/ansible/hosts

ssh-keygen

# Ввод хостнейма, ssh порта и юзера сервера
echo IP/FQDN сервера?

read srvip

echo Порт сервера?

read srvport

echo Юзер на сервере?

read srvuser

# Копирование ssh ключа на сервер
ssh-copy-id $srvuser@$srvip -p $srvport

# Прописываем сервак в конфиг ансибла
echo 'Добавляем сервак в hosts ansible' | cowsay
echo proxy ansible_port=$srvport ansible_ssh_host=$srvip >> /etc/ansible/hosts

#Настройка Ansible для подключения к группе серверов с помощью заданного пользователя. Создание каталога
mkdir /etc/ansible/group_vars

# В нем нужно создать YAML-файлы для каждой группы хостов.
touch /etc/ansible/group_vars/mtproto
cat <<EOF > /etc/ansible/group_vars/mtproto
ansible_ssh_user: $srvuser
EOF

# Создание симлинка на каталог с плейбуками, что бы не писать много каждый раз
cowsay 'симлинк плейбуков в /play'
mkdir /etc/ansible/playbooks
ln -s /etc/ansible/playbooks /play

# На всякий случай скачивание модуля управления SELinux для Ansible
cowsay 'Скачиваем модуль управления SELinux'
git clone https://github.com/ericsysmin/ansible-role-selinux.git /etc/ansible/roles/ericsysmin.selinux

## Запускаем Ansible
# Гасим SELinux и Firewalld
ansible-playbook /play/selinux.yml
ansible-playbook /play/firewalld.yml
# Ставим и включаем всю хуйню
ansible-playbook /play/depend.yml
# Доустанавливаем dante-server ( SOCKS5 )
ansible-playbook /play/socks.yml
# Записываем авторизационные данные
ssh $srvuser@$srvip -p $srvport 'touch /etc/mtproxy/sec.txt'
ssh $srvuser@$srvip -p $srvport 'touch /etc/mtproxy/port.txt'
ssh $srvuser@$srvip -p $srvport 'cat /etc/mtproxy/secret' > /usr/src/sec.txt
ssh $srvuser@$srvip -p $srvport 'cat /etc/mtproxy/mtproxy.params | grep MTPROXY_CLIENT_PORT=443 > /etc/mtproxy/port.txt'
ssh $srvuser@$srvip -p $srvport 'cat /etc/mtproxy/sec.txt'
ssh $srvuser@$srvip -p $srvport 'cat /etc/mtproxy/port.txt'

# Готовим конфиг данте сервера
ssh $srvuser@$srvip -p $srvport 'mkdir /var/run/sockd'
ssh $srvuser@$srvip -p $srvport 'mv /etc/sockd.conf /etc/sockd.conf.orig'

cat <<EOF > /etc/sockd.conf
user.privileged: root
user.unprivileged: nobody

# The listening network interface or address.
internal: 0.0.0.0 port=10443
#internal: 0.0.0.0 port=1080 # можно указать несколько портов, по умолчанию 1080

# The proxying network interface or address. Сюда подставить имя интерфейса с удаленного сервера, на него будет биндится сервер
external: eth0

logoutput: syslog stdout /var/log/sockd.log
errorlog: /var/log/sockd_err.log
# socks-rules determine what is proxied through the external interface.
# The default of "none" permits anonymous access.
socksmethod: username

# client-rules determine who can connect to the internal interface.
# The default of "none" permits anonymous access.
clientmethod: none

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
EOF

# Отправляем конфиг на сервер
scp -P $srvport /etc/sockd.conf $srvuser@$srvip:/etc/sockd.conf

# Включаем и запускаем Sokcs сервер
ssh $srvuser@$srvip -p $srvport 'systemctl enable sockd.service'
ssh $srvuser@$srvip -p $srvport 'systemctl start sockd.service'

## Берем вырезанный из конфига secret в переменную
# Форматируем текст до отображения только хеша
cut -c 16- /usr/src/sec.txt > /usr/src/secc.txt
# И записываем результат в переменную
read secret < /usr/src/secc.txt
sed -i "s|c_secret=yousecret|c_secret=$secret|g" /usr/src/secret.sh

# Оповещаем о обновлении настроек прокси в чат телеграма
bash /usr/src/scripts/telegram.sh chatid 'Настройки прокси сервера изменены ( обычно вам нужно будет только обновить secret)' 'HOST: ваш хостнейм или ip\n Port: Ваш порт \n Secret в следующем сообщении'
bash /usr/src/scripts/secret.sh

ssh $srvuser@$srvip -p $srvport 'reboot'

cowsay 'Дождитесь ребута сервера'

exit
