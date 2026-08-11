#!/bin/bash

# ПРОВЕРКА: Если ты не заменил YOUR_HF_USERNAME, скрипт попытается взять его из окружения
REPO_NAME="vibe-data"
DATASET_REPO="${HF_USERNAME}/${REPO_NAME}"
LOCAL_DATA="/home/user/app/pb_data"

mkdir -p $LOCAL_DATA

# 1. Попытка скачать существующую базу из Dataset
echo "Downloading data from $DATASET_REPO..."
huggingface-cli download $DATASET_REPO --repo-type dataset --local-dir $LOCAL_DATA || echo "Dataset is empty or not found yet. Starting fresh."

# 2. Функция для периодического сохранения данных (раз в 5 минут)
sync_data() {
  while true; do
    sleep 300
    echo "Backing up pb_data to Hugging Face Hub..."
    huggingface-cli upload $DATASET_REPO $LOCAL_DATA . --repo-type dataset --token $HF_TOKEN || echo "Sync failed. Check HF_TOKEN."
  done
}

# 3. Запуск фоновой синхронизации
sync_data &

# 4. Запуск PocketBase
echo "Starting Vibe Server (PocketBase)..."
/pb/pocketbase serve --http="0.0.0.0:7860" --dir=$LOCAL_DATA
