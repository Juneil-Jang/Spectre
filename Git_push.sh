#!/bin/bash
echo "========================================"
echo "  ⬆️ Push (Upload) the code  "
echo "========================================"
echo ""

# 1. 변경된 파일 추적
git add .

# 2. 커밋 메시지 입력받기
echo -n "Enter the comment:"
read msg

if [ -z "$msg" ]; then
    msg="Auto-sync from Ubuntu: $(date +'%Y-%m-%d %H:%M:%S')"
fi

# 3. 확정 및 업로드
git commit -m "$msg"
git push origin main

echo ""
echo "========================================"
echo "  Code Uploaded Successfully!"
echo "========================================"
