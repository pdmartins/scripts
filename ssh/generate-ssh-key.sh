#!/bin/bash

# Cores ANSI
YELLOW='\033[33m'
CYAN='\033[36m'
WHITE='\033[37m'
GRAY='\033[90m'
GREEN='\033[32m'
RED='\033[31m'
RESET='\033[0m'

# Função para verificar e tratar chaves existentes
resolve_existing_key() {
    local key_name="$1"
    local ssh_directory="$2"
    
    # Remover prefixo "id_" se o usuário digitou
    if [[ "$key_name" == id_* ]]; then
        key_name="${key_name:3}"
    fi
    
    local key_path="$ssh_directory/id_$key_name"
    
    # Se a chave não existe, retorna o nome
    if [[ ! -f "$key_path" ]]; then
        echo "$key_name"
        return
    fi
    
    # Chave existe - exibir informações
    echo -e "\n${YELLOW}⚠️  A chave '$key_path' já existe!${RESET}"
    
    # Exibir conteúdo da chave pública existente
    local public_key_path="$key_path.pub"
    if [[ -f "$public_key_path" ]]; then
        echo -e "\n${CYAN}📄 Conteúdo da chave pública existente:${RESET}"
        echo -e "${WHITE}$(cat "$public_key_path")${RESET}"
    fi
    
    echo -e "\n${GRAY}🤔 O que deseja fazer?${RESET}"
    echo -e "${GRAY}  ↩️ ENTER - Reescrever o arquivo existente${RESET}"
    echo -e "${GRAY}  ✏️ Digite um novo nome - Gerar com outro nome${RESET}"
    echo -e "${GRAY}  ⛔ Digite 'sair' ou pressione Ctrl+C para cancelar${RESET}"
    
    # Capturar a entrada
    echo -en "\n${GRAY}👉 Digite: ${RESET}"
    read -r response
    
    if [[ -z "$response" ]]; then
        # ENTER pressionado - reescrever
        echo -e "\n${YELLOW}🔄 Reescrevendo o arquivo existente...${RESET}"
        echo "$key_name"
        return
    fi
    
    # Converter para minúsculas
    local response_lower=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$response_lower" == "sair" ]] || [[ "$response_lower" == "s" ]] || [[ "$response_lower" == "stop" ]]; then
        # "sair" digitado
        echo -e "\n${RED}❌ Operação cancelada.${RESET}"
        exit 0
    else
        # Novo nome digitado - verificar recursivamente
        resolve_existing_key "$response" "$ssh_directory"
    fi
}

# Parâmetros
email="$1"
name="$2"

# Se o email não foi fornecido, solicitar
if [[ -z "$email" ]]; then
    echo -n "📧 Digite o email: "
    read -r email
fi

# Extrair o prefixo do email
email_prefix="${email%%@*}"

# Se o nome não foi fornecido, solicitar
if [[ -z "$name" ]]; then
    echo -en "${GRAY}🔑 Digite o nome da chave (deixe em branco para usar ${RESET}"
    echo -en "${YELLOW}$email_prefix${RESET}"
    echo -en "${GRAY}): ${RESET}"
    read -r name
fi

# Se o nome estiver em branco, usar o prefixo antes do @ do email
if [[ -z "$name" ]]; then
    name="$email_prefix"
    echo -e "${GRAY}✨ Usando '${RESET}${YELLOW}$email_prefix${RESET}${GRAY}' como nome da chave (extraído do email)${RESET}"
fi

# Remover prefixo "id_" se o usuário digitou
if [[ "$name" == id_* ]]; then
    name="${name:3}"
    echo -e "${YELLOW}📌 Removido prefixo 'id_' duplicado. Usando: $name${RESET}"
fi

# Construir o caminho completo do arquivo (sempre em ~/.ssh)
ssh_dir="$HOME/.ssh"
if [[ ! -d "$ssh_dir" ]]; then
    mkdir -p "$ssh_dir"
    echo -e "${GREEN}📁 Diretório .ssh criado em: $ssh_dir${RESET}"
fi

# Verificar e resolver nome da chave (tratando duplicatas)
name=$(resolve_existing_key "$name" "$ssh_dir")
key_path="$ssh_dir/id_$name"

echo -e "\n${CYAN}🔐 Gerando chave SSH id_$name${RESET}"
echo -e "${WHITE}📝 ssh-keygen -t ed25519 -C \"$email\" -f \"$key_path\" -N \"\"\n${RESET}"

# Executar o ssh-keygen (com passphrase vazia e sobrescrever sem perguntar)
yes y 2>/dev/null | ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""

# Verificar se a chave foi gerada com sucesso
if [[ $? -eq 0 ]]; then
    echo -e "\n${GREEN}=================================${RESET}"
    echo -e "${GREEN}✅ Chave SSH gerada com sucesso!${RESET}"
    echo -e "${GREEN}=================================${RESET}"
    
    # Exibir o conteúdo da chave pública
    public_key_path="$key_path.pub"
    
    if [[ -f "$public_key_path" ]]; then
        echo -e "\n${CYAN}📋 Conteúdo da chave pública (copie o texto abaixo):${RESET}"
        echo -e "${WHITE}$(cat "$public_key_path")${RESET}"
    else
        echo -e "\n${RED}⚠️  Aviso: Não foi possível encontrar o arquivo da chave pública em: $public_key_path${RESET}"
    fi
else
    echo -e "\n${RED}❌ Erro ao gerar a chave SSH!${RESET}"
fi
