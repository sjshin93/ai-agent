import logging
import re

import paramiko

from app.core.config import settings

logger = logging.getLogger(__name__)


class SshService:
    _site_id_pattern = re.compile(r"^\d+$")
    _allowed_commands = {
        "top": "top -b -n 1",
        "free": "free -m",
    }

    def fetch_top(self, site_id: str, command: str | None = None) -> str:
        if not self._site_id_pattern.match(site_id):
            raise ValueError("Invalid site_id")
        command_key = (command or "top").strip().lower()
        if command_key not in self._allowed_commands:
            raise ValueError("Command not allowed")
        if not settings.aws_ssh_host:
            raise RuntimeError("AWS_SSH_HOST not configured")
        if not settings.aws_ssh_user:
            raise RuntimeError("AWS_SSH_USER not configured")
        if not settings.aws_ssh_key_path:
            raise RuntimeError("AWS_SSH_KEY_PATH not configured")

        logger.info("SSH: connecting to AWS host %s:%s", settings.aws_ssh_host, settings.aws_ssh_port)
        key = paramiko.RSAKey.from_private_key_file(settings.aws_ssh_key_path)
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            client.connect(
                hostname=settings.aws_ssh_host,
                port=settings.aws_ssh_port,
                username=settings.aws_ssh_user,
                pkey=key,
                timeout=10,
            )
            logger.info("SSH: connected to AWS. running serverA command via ssh_%s", site_id)
            # Use login shell so ssh_{site_id} aliases/functions are available.
            # Source ~/.bash_aliases only if present, and disable echo to avoid leaking passwords.
            aliases_path = settings.aws_ssh_aliases_path
            remote_cmd = self._allowed_commands[command_key]
            cmd = (
                "bash -lc \""
                "shopt -s expand_aliases; "
                f"if [ -f {aliases_path} ]; then "
                f"source {aliases_path}; "
                "fi; "
                f"eval \\\"stty -echo; ssh_{site_id} '{remote_cmd}'; stty echo\\\"\""
            )
            stdin, stdout, stderr = client.exec_command(cmd, timeout=20, get_pty=True)
            channel = stdout.channel

            output_chunks: list[str] = []
            err_chunks: list[str] = []
            password_sent = False

            while not channel.exit_status_ready():
                if channel.recv_ready():
                    chunk = channel.recv(4096).decode("utf-8", errors="ignore")
                    output_chunks.append(chunk)
                    if (
                        not password_sent
                        and settings.ssh_target_password
                        and "password" in chunk.lower()
                    ):
                        stdin.write(f"{settings.ssh_target_password}\n")
                        stdin.flush()
                        password_sent = True
                if channel.recv_stderr_ready():
                    chunk = channel.recv_stderr(4096).decode("utf-8", errors="ignore")
                    err_chunks.append(chunk)
                    if (
                        not password_sent
                        and settings.ssh_target_password
                        and "password" in chunk.lower()
                    ):
                        stdin.write(f"{settings.ssh_target_password}\n")
                        stdin.flush()
                        password_sent = True

            # Drain any remaining output after exit.
            while channel.recv_ready():
                output_chunks.append(channel.recv(4096).decode("utf-8", errors="ignore"))
            while channel.recv_stderr_ready():
                err_chunks.append(channel.recv_stderr(4096).decode("utf-8", errors="ignore"))
            channel.recv_exit_status()

            output = "".join(output_chunks)
            err = "".join(err_chunks)
            output = re.sub(r"(?i)^.*password:\s*$", "", output, flags=re.MULTILINE).strip()
            err = re.sub(r"(?i)^.*password:\s*$", "", err, flags=re.MULTILINE).strip()
            combined = f"{output}\n{err}".lower()

            if "command not found" in combined:
                logger.warning("SSH: serverA command not found for ssh_%s", site_id)
                raise RuntimeError(f"ServerA command not found: ssh_{site_id}")
            if "password" in combined and "permission denied" in combined:
                logger.warning("SSH: serverA authentication failed")
                raise RuntimeError("ServerA authentication failed")
            if "password" in combined and not settings.ssh_target_password:
                logger.warning("SSH: serverA password required but not provided")
                raise RuntimeError("ServerA password required")
            if err.strip():
                logger.warning("SSH: serverA command error: %s", err.strip())
                raise RuntimeError(f"ServerA error: {err.strip()}")

            if not output.strip():
                logger.warning("SSH: serverA command returned empty output")
                raise RuntimeError("ServerA returned empty output")

            logger.info("SSH: serverA command succeeded (output size=%d)", len(output))
            return output.strip()
        except paramiko.AuthenticationException as exc:
            logger.error("SSH: AWS authentication failed: %s", exc)
            raise RuntimeError("AWS SSH authentication failed") from exc
        except paramiko.SSHException as exc:
            logger.error("SSH: AWS SSH error: %s", exc)
            raise RuntimeError("AWS SSH connection error") from exc
        except TimeoutError as exc:
            logger.error("SSH: AWS connection timed out: %s", exc)
            raise RuntimeError("AWS SSH connection timed out") from exc
        finally:
            client.close()
