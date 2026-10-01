#!/usr/bin/env python3
html = open("/tmp/miko.html", encoding="utf-8", errors="ignore").read()
for key in ["Модули", "Обслуживание", "Телефония", "Маршрутизация", "Система"]:
    j = html.find(key)
    print("===", key, "idx", j)
    if j != -1:
        chunk = html[max(0, j - 250) : j + 150].replace("\n", " ")
        print(chunk)
        print()
