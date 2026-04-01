#!/bin/bash
echo "🚀 RwandaCare Presentation Mode - Starting Web Headquarters..."
cd "$(dirname "$0")/RwandaCare_Web_HQ"

export DJANGO_SUPERUSER_PASSWORD="admin"
/Users/user/Desktop/RwandaCare/.venv/bin/python manage.py migrate
/Users/user/Desktop/RwandaCare/.venv/bin/python manage.py runserver &
sleep 2
open "http://127.0.0.1:8000/"
echo "✅ Backend Web App is running. You can now press Cmd+R in Xcode to launch the iOS App!"
