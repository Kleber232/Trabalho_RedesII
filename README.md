# Projeto Redes II — TCP vs UDP vs QUIC

Status: **Fase 1-2 concluída** (ambiente Docker + NGINX com HTTP/1.1, HTTP/2 e
HTTP/3, + client com curl-HTTP/3, iperf3, tshark e Python).

## Como buildar e subir

```bash
cd projeto-redes2
docker compose build      # build pode demorar (compila NGINX e curl do zero)
docker compose up -d
docker compose logs -f server   # confirme "start worker processes" sem erro
```

## Como verificar se está tudo funcionando

```bash
docker compose exec client bash /workspace/../client/verify_setup.sh
```

(ou copie `client/verify_setup.sh` para dentro do container e rode manualmente)

Isso testa, contra o `server`:
- HTTP/1.1 puro (porta 80/tcp)
- HTTP/2 sobre TLS 1.3 (porta 443/tcp)
- HTTP/3 sobre QUIC (porta 443/udp)
- iperf3 via UDP

## Estrutura atual

```
projeto-redes2/
├── docker-compose.yml
├── server/
│   ├── Dockerfile          # compila NGINX 1.27.x + quictls com --with-http_v3_module
│   ├── nginx.conf          # 3 server blocks: :80 (h1), :443/tcp (h2+tls1.3), :443/udp (h3/quic)
│   └── entrypoint.sh       # gera certs, arquivos de teste (100M/500M/1G + 100 objetos pequenos), sobe iperf3 -s e nginx
├── client/
│   ├── Dockerfile          # compila curl + ngtcp2 + nghttp3 + quictls (suporte a --http3)
│   └── verify_setup.sh     # smoke test manual dos 3 protocolos
├── netem/                  # (próxima fase) scripts tc/NetEm por cenário
├── analysis/                # (próxima fase) parsing de .pcapng + geração de gráficos
├── results/
│   ├── raw/                 # .pcapng e logs brutos
│   └── figures/              # gráficos exportados
└── report/                   # (fase final) artigo LaTeX no padrão SBC/SBRC
```

## Pontos de atenção / riscos conhecidos

1. **Tempo de build**: compilar NGINX + quictls e curl + ngtcp2/nghttp3 do
   zero pode levar vários minutos por imagem. Isso é esperado.
2. **Compatibilidade de versões**: as versões fixadas nos `ARG` dos
   Dockerfiles (`NGINX_VERSION`, `QUICTLS_VERSION`, `NGTCP2_VERSION`,
   `NGHTTP3_VERSION`, `CURL_VERSION`) são um ponto de partida razoável, mas
   combinações de libs QUIC quebram com frequência entre releases. Se o
   build falhar, o primeiro passo é checar a documentação oficial de cada
   projeto por combinações de versão testadas/compatíveis.
3. **Portas UDP em Docker**: o mapeamento `443:443/udp` no `docker-compose.yml`
   é necessário para o HTTP/3 funcionar fora do container — confirme que o
   host permite tráfego UDP na porta se for testar de fora da rede Docker.
4. **`cap_add: NET_ADMIN`**: já está configurado em ambos os serviços, é o
   que vai permitir rodar `tc/NetEm` dentro dos containers na próxima fase.

## Próximas fases (ainda não implementadas)

- **Fase 4**: scripts `netem/cenario_a.sh`, `cenario_b.sh`, `cenario_c.sh`
  aplicando `tc qdisc netem` com os parâmetros de cada cenário.
- **Fase 5**: `run_experiments.sh` orquestrando tudo (sobe ambiente → aplica
  netem → roda ≥10 repetições por ponto de teste com curl/iperf3 → captura
  com tshark → salva em `results/raw/`).
- **Fase 7**: scripts em `analysis/` (pandas/matplotlib) para calcular FCT
  (média, p90, p95), goodput, overhead e gerar os gráficos finais.
- **Fase 8-9**: relatório SBC/SBRC e vídeo de 15 minutos.

Quando quiser seguir, me avisa qual fase atacar (netem, run_experiments.sh,
ou já a análise/relatório).
