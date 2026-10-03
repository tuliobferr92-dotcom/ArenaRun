# REINOS — servidor de multiplayer online

Relay WebSocket server-authoritative (seções 36/37 do spec): o servidor
guarda o único `GameState` válido de cada partida online e aplica toda
jogada através do mesmo `GameEngine.apply` que o app usa localmente —
nenhuma lógica de jogo é duplicada entre cliente e servidor.

## O que já está testado

`server/test/relay_server_test.dart` sobe o servidor real (mesmo código do
`bin/server.dart`) numa porta local efêmera e conecta dois clientes
WebSocket de verdade para verificar: criar sala, entrar por código,
sincronizar `GameState` entre os dois lados após uma jogada, e rejeitar
uma ação que tenta agir em nome de outro jogador. Roda com:

```
cd server
dart pub get
dart test
```

**O que NÃO foi verificado neste ambiente:** o `docker build` real do
`Dockerfile` abaixo — este container não tem um daemon Docker disponível,
então o Dockerfile segue o padrão oficial do time do Dart para
`dart compile exe` + imagem `scratch`, mas não foi testado localmente.
Recomendo rodar `docker build` e um smoke test de conexão antes do
primeiro deploy em produção.

## Protocolo (JSON sobre WebSocket)

Cliente → servidor:
- `{"type":"createRoom","mapId":"biblical_lands_v1","hostPlayerId":"p0","seed":1,"players":[{"id":"p0","displayName":"...","color":"blue"},{"id":"p1","displayName":"...","color":"red","isBot":false}]}`
- `{"type":"joinRoom","roomCode":"REINO-7281","playerId":"p1"}`
- `{"type":"action","roomCode":"REINO-7281","playerId":"p1","action":{...}}` — `action` é o `GameAction.toJson()` de qualquer uma das 8 subclasses (`packages/reinos_engine/lib/game_engine/state/game_action.dart`)

Servidor → cliente:
- `{"type":"roomCreated"|"joined","roomCode":"...","playerId":"...","state":{...}}`
- `{"type":"stateUpdate","roomCode":"...","state":{...},"appliedActions":[...]}`
- `{"type":"playerConnected"|"playerDisconnected","roomCode":"...","playerId":"..."}`
- `{"type":"error","message":"..."}`

Bots (`isBot: true` na config) são jogados pelo próprio servidor
(`lib/bot_driver.dart`, espelhando o loop de bot do app offline) — o
cliente nunca precisa enviar ações por um bot.

## Deploy

O servidor depende do pacote `../packages/reinos_engine` por caminho
relativo, então o **build sempre usa a raiz do repositório como
contexto**, nunca `server/` isoladamente.

### Fly.io
```
fly launch --copy-config --no-deploy   # primeira vez, lê server/fly.toml
fly deploy --config server/fly.toml --dockerfile server/Dockerfile .
```

### Render / Railway (ou qualquer host que builda a partir de um Dockerfile)
Configure:
- **Dockerfile path:** `server/Dockerfile`
- **Docker build context:** raiz do repositório (`.`), não `server/`
- **Porta:** o servidor lê `$PORT` (padrão 8080) — já é a convenção de
  todos os três hosts, nada a configurar manualmente.

### VPS genérica (sem Docker)
```
cd server
dart pub get
dart compile exe bin/server.dart -o server_bin
PORT=8080 ./server_bin
```
Rode isso atrás de um `systemd` service ou `screen`/`tmux` para persistir
após desconectar do SSH.

## Variáveis de ambiente

- `PORT` — porta HTTP/WebSocket a escutar (padrão `8080`, a maioria dos
  hosts injeta automaticamente).

## Manutenção

`server/data/maps/` e `server/data/rules/` são cópias dos arquivos em
`data/maps/` e `data/rules/` na raiz do repo (o servidor não tem acesso ao
`rootBundle` do Flutter). **Sempre que o mapa ou as regras padrão mudarem,
copie os arquivos atualizados para `server/data/` também** — não há
sincronização automática.
