import subprocess
import sys

# Путь к скомпилированному бинарнику
BINARY = "./app/DO"


def run_test(args, expected_output, expected_code):
    """
    Запускает бинарник с аргументами и проверяет вывод и код возврата.
    """
    # Формирование команды: бинарник + аргументы
    cmd = [BINARY] + args

    # Запуск процесса, захват stdout и stderr
    result = subprocess.run(cmd, capture_output=True, text=True)

    # Проверк кода возврата
    if result.returncode != expected_code:
        print(f"FAIL: args={args}")
        print(f"  Expected code: {expected_code}, Got: {result.returncode}")
        print(f"  Stdout: {result.stdout.strip()}")
        sys.exit(1)

    # Проверка наличия ожидаемой подстроки в выводе
    if expected_output not in result.stdout:
        print(f"FAIL: args={args}")
        print(f"  Expected output containing: '{expected_output}'")
        print(f"  Got: '{result.stdout.strip()}'")
        sys.exit(1)

    # Если всё ок, выводим успех
    print(f"PASS: args={args} -> '{expected_output}' (code {expected_code})")


if __name__ == "__main__":
    print("Starting integration tests...")

    # Тест 1: Без аргументов (ожидаем код 255 и сообщение об ошибке)
    run_test([], "Bad number of arguments!", 255)

    # Тест 2: Аргумент 1
    run_test(["1"], "Learning to Linux", 0)

    # Тест 3: Аргумент 6
    run_test(["6"], "Learning to CI/CD", 0)

    # Тест 4: Неверный аргумент (7)
    run_test(["7"], "Bad number!", 254)

    print("All integration tests passed successfully!")
    sys.exit(0)
