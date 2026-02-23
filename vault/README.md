# Vault 설정 (Community Edition)

이 프로젝트는 Docker Compose로 Vault와 Vault Agent를 실행합니다. Vault에는 SSH 개인키를 저장하고, Vault Agent가 이를 파일로 렌더링하여 API가 읽습니다.

## 저장 위치
- Vault 데이터: Docker 볼륨 `vault_data`
- 렌더링된 키 파일: `/vault/secrets/aws_ssh_key.pem` (볼륨 `vault_secrets`)
- Role/Secret ID: `vault/agent/role_id`, `vault/agent/secret_id` (커밋 금지)

## 사전 준비
- Docker + Docker Compose
- `.env` 설정 ( `.env.example` 참고)
- 호스트에 SSH 개인키 파일 존재

## 초기 셋업 (처음 1회)
1. Vault + Agent 실행:
```bash
docker compose up -d vault vault-agent
```

2. Vault 초기화 및 언실:
```bash
VAULT_ADDR=http://127.0.0.1:8200 docker compose exec vault vault operator init -key-shares=1 -key-threshold=1
VAULT_ADDR=http://127.0.0.1:8200 docker compose exec vault vault operator unseal <UNSEAL_KEY>
VAULT_ADDR=http://127.0.0.1:8200 docker compose exec vault vault login <ROOT_TOKEN>
```

3. 셋업 스크립트 실행:
```bash
export UNSEAL_KEY=<UNSEAL_KEY>
export VAULT_TOKEN=<ROOT_TOKEN>
export SSH_KEY_FILE=/absolute/path/to/aws_key.pem
bash vault/scripts/setup.sh
```

4. 전체 서비스 실행:
```bash
docker compose up -d
```

## 재배포 / 재시작
서버 재부팅이나 Vault 재시작 시 Vault가 sealed 상태가 될 수 있습니다. 아래를 실행하세요:
```bash
export UNSEAL_KEY=<UNSEAL_KEY>
export VAULT_TOKEN=<ROOT_TOKEN>
export SSH_KEY_FILE=/absolute/path/to/aws_key.pem
bash vault/scripts/redeploy.sh
docker compose restart api
```

## 참고
- `vault/agent/role_id`, `vault/agent/secret_id`, `vault/agent/token`, 그리고 unseal/root 토큰은 절대 커밋하지 마세요.
- `.env`의 `AWS_SSH_KEY_PATH`는 `/vault/secrets/aws_ssh_key.pem`로 설정해야 합니다.
- Vault가 sealed 상태이면, 비밀 발급 전에 반드시 unseal 해야 합니다.
