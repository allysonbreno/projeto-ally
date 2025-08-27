# 🎮 PROJETO ALLY - SERVIDOR MULTIPLAYER

Servidor dedicado em Python para o jogo Projeto Ally, criado com WebSockets e interface gráfica em tkinter.

## 📋 Funcionalidades

### 🖥️ Interface Gráfica
- **Ligar Servidor**: Inicia o servidor WebSocket
- **Desligar Servidor**: Para o servidor graciosamente
- **Reiniciar Servidor**: Reinicia o servidor automaticamente
- **Monitor em Tempo Real**: Jogadores online, conexões ativas
- **Logs Detalhados**: Histórico completo de atividades
- **Configurações**: Host e porta personalizáveis

### 🌐 Funcionalidades de Rede
- **WebSocket Server**: Comunicação em tempo real
- **Sistema de Login**: Autenticação por nome único
- **Sincronização Total**: Posição, velocidade, animações, ações
- **Broadcast**: Atualização simultânea para todos os jogadores
- **Gerenciamento de Sessão**: Controle completo de conexões

## 🚀 Como Usar

### 1. Instalar Dependências
```bash
cd server
pip install -r requirements.txt
```

### 2. Executar Servidor
```bash
python run_server.py
```

### 3. Interface
1. **Configurar** host e porta (padrão: localhost:8765)
2. **Clicar "Ligar Servidor"**
3. **Monitorar** jogadores conectados
4. **Acompanhar logs** em tempo real

## 🔧 Configuração

### Configurações Padrão
- **Host**: localhost
- **Porta**: 8765
- **Protocolo**: WebSocket (ws://)

### Para Acesso Externo
1. Alterar host para `0.0.0.0`
2. Configurar firewall (porta 8765)
3. Usar IP público/local na rede

## 📡 Protocolo de Comunicação

### Mensagens do Cliente → Servidor

#### Login
```json
{
    "type": "login",
    "player_name": "NomeDoJogador"
}
```

#### Atualização do Jogador
```json
{
    "type": "player_update",
    "position": {"x": 100, "y": 350},
    "velocity": {"x": 0, "y": 0},
    "animation": "walk",
    "facing": 1,
    "hp": 95
}
```

#### Ação do Jogador
```json
{
    "type": "player_action",
    "action": "attack",
    "action_data": {
        "position": {"x": 120, "y": 350}
    }
}
```

### Mensagens do Servidor → Cliente

#### Resposta de Login
```json
{
    "type": "login_response",
    "success": true,
    "player_id": "abc123",
    "player_info": {
        "id": "abc123",
        "name": "NomeDoJogador",
        "position": {"x": 100, "y": 350},
        "velocity": {"x": 0, "y": 0},
        "animation": "idle",
        "facing": 1,
        "hp": 100
    }
}
```

#### Lista de Jogadores
```json
{
    "type": "players_list",
    "players": {
        "abc123": {
            "id": "abc123",
            "name": "Jogador1",
            "position": {"x": 100, "y": 350}
        }
    }
}
```

#### Sincronização
```json
{
    "type": "player_sync",
    "player_id": "abc123",
    "player_info": {
        "position": {"x": 150, "y": 350},
        "velocity": {"x": 50, "y": 0},
        "animation": "walk"
    }
}
```

## 🎯 Próximos Passos

1. **✅ Servidor Python criado**
2. **🔄 Próximo**: Modificar Godot para conectar via WebSocket
3. **🔄 Depois**: Sistema de salas/rooms
4. **🔄 Futuro**: Persistência de dados, ranking

## 🐛 Troubleshooting

### Erro "Address already in use"
- Trocar porta nas configurações
- Ou aguardar alguns segundos após fechar

### "Connection refused"
- Verificar se servidor está ligado
- Confirmar host/porta corretos
- Checar firewall

### Performance
- Monitor uso de CPU/RAM na interface
- Logs podem ser limpos durante execução