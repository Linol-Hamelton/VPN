#!/usr/bin/env python3
"""
Тесты для VPN скриптов
"""

import os
import subprocess
import pytest
from pathlib import Path


class TestScripts:
    """Тесты для bash скриптов"""

    def test_script_exists(self):
        """Проверка существования скриптов"""
        scripts = [
            "install-full-vpn.sh",
            "install-wireguard-xray.sh",
            "install-vpn-panel.sh",
            "vpn-maintenance.sh"
        ]

        for script in scripts:
            assert Path(script).exists(), f"Скрипт {script} не найден"
            assert os.access(script, os.X_OK), f"Скрипт {script} не исполняемый"

    def test_script_syntax(self):
        """Проверка синтаксиса bash скриптов"""
        import platform

        scripts = [
            "install-full-vpn.sh",
            "install-wireguard-xray.sh",
            "install-vpn-panel.sh",
            "vpn-maintenance.sh"
        ]

        # На Windows bash может быть недоступен, проверяем наличие shebang
        for script in scripts:
            with open(script, 'r', encoding='utf-8') as f:
                first_line = f.readline().strip()
                assert first_line == "#!/bin/bash", f"Неверный shebang в {script}: {first_line}"

            # Базовая проверка на распространенные синтаксические ошибки
            content = Path(script).read_text(encoding='utf-8')

            # Проверка на незакрытые кавычки
            single_quotes = content.count("'") % 2
            double_quotes = content.count('"') % 2
            backticks = content.count('`') % 2

            assert single_quotes == 0, f"Незакрытые одинарные кавычки в {script}"
            assert double_quotes == 0, f"Незакрытые двойные кавычки в {script}"
            assert backticks == 0, f"Незакрытые обратные кавычки в {script}"

            # Проверка на незакрытые скобки (базовая)
            open_braces = content.count('{')
            close_braces = content.count('}')
            assert open_braces == close_braces, f"Несбалансированные фигурные скобки в {script}"

            open_parens = content.count('(')
            close_parens = content.count(')')
            assert open_parens == close_parens, f"Несбалансированные круглые скобки в {script}"

    def test_config_files(self):
        """Проверка конфигурационных файлов"""
        config_files = [
            "config/templates/wg0.conf",
            "config/templates/config.json",
            ".env.example"
        ]

        for config in config_files:
            assert Path(config).exists(), f"Конфиг {config} не найден"

    def test_docker_files(self):
        """Проверка Docker файлов"""
        docker_files = [
            "docker/Dockerfile.wireguard",
            "docker/Dockerfile.xray",
            "docker/docker-compose.yml"
        ]

        for docker_file in docker_files:
            assert Path(docker_file).exists(), f"Docker файл {docker_file} не найден"


class TestEnvironment:
    """Тесты переменных окружения"""

    def test_env_example(self):
        """Проверка .env.example файла"""
        env_file = Path(".env.example")
        assert env_file.exists()

        content = env_file.read_text()
        required_vars = [
            "SERVER_IP",
            "WG_CLIENTS",
            "XRAY_UUID",
            "SHADOWSOCKS_PASSWORD"
        ]

        for var in required_vars:
            assert var in content, f"Переменная {var} отсутствует в .env.example"

    def test_gitignore(self):
        """Проверка .gitignore"""
        gitignore = Path(".gitignore")
        assert gitignore.exists()

        content = gitignore.read_text()
        sensitive_patterns = [".env", "*.log", "wireguard-clients/"]

        for pattern in sensitive_patterns:
            assert pattern in content, f"Паттерн {pattern} отсутствует в .gitignore"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])