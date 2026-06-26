# Báo Cáo Lab MLOps — Day 21

**Sinh viên:** Võ Thanh Hiệp  
**Mã số:** 2A202600836  
**Repo:** https://github.com/thanhhiepvo/2A202600836-VoThanhHiep-Day21  
**Cloud provider:** AWS (S3 + EC2)

---

## 1. Bộ siêu tham số đã chọn

Sau khi chạy nhiều thí nghiệm trên tập `train_phase1.csv` (2.998 mẫu) và đánh giá trên `eval.csv` (500 mẫu, held-out), các cấu hình tiêu biểu:

| Lần chạy | n_estimators | max_depth | min_samples_split | Accuracy | F1 (weighted) |
|---|---:|---|---:|---:|---:|
| 1 | 100 | 5 | 2 | 0.564 | — |
| 2 | 50 | 3 | 2 | 0.558 | — |
| 3 | 200 | 10 | 5 | 0.642 | — |
| **Tốt nhất (phase 1)** | **300** | **null** | **2** | **0.686** | **~0.685** |

**Bộ siêu tham số cuối cùng trong `params.yaml`:**

```yaml
n_estimators: 300
max_depth: null
min_samples_split: 2
```

**Lý do chọn:** `max_depth: null` cho phép cây phát triển đủ sâu; tăng `n_estimators` lên 300 cải thiện accuracy từ ~0.56–0.64 lên **0.686**, cao nhất trong các lần thử với chỉ `train_phase1`. Mô hình dùng `RandomForestClassifier` với `random_state=42` để đảm bảo tái lập kết quả.

---

## 2. So sánh Bước 2 và Bước 3

| Chỉ số | Bước 2 (2.998 mẫu train) | Bước 3 (5.996 mẫu train) |
|---|---:|---:|
| accuracy | 0.686 | **0.754** |
| f1_score | ~0.685 | **0.753** |

Sau khi chạy `add_new_data.py` (ghép `train_phase2.csv` vào `train_phase1.csv`), mô hình được huấn luyện lại trên 5.996 mẫu. Accuracy tăng **~6.8 điểm phần trăm**, cho thấy thêm dữ liệu giúp mô hình tổng quát hóa tốt hơn trên tập đánh giá cố định.

**Lưu ý về eval gate (≥ 0.70):** Với chỉ 2.998 mẫu huấn luyện, accuracy đạt tối đa ~0.686 (dưới ngưỡng 0.70). Pipeline CI/CD vì vậy cần dữ liệu đã gộp (Bước 3) để vượt ngưỡng và cho phép deploy.

---

## 3. Kiến trúc đã triển khai

- **Bước 1:** MLflow tracking cục bộ (`sqlite:///mlflow.db`), ≥ 3 thí nghiệm.
- **Bước 2:** DVC + S3 (`mlops-vothanhhiep-744815815163`), GitHub Actions (Test → Train → Eval → Deploy), FastAPI trên EC2 (`100.54.217.84:8000`).
- **Bước 3:** Cập nhật `train_phase1.csv.dvc`, `dvc push`, `git push` — pipeline chạy lại tự động.

---

## 4. Khó khăn gặp phải và cách giải quyết

| Khó khăn | Cách giải quyết |
|---|---|
| `git push` bị từ chối khi cập nhật `.github/workflows/mlops.yml` (thiếu scope `workflow`) | Push code/DVC trước; đẩy workflow qua GitHub API bằng Personal Access Token có scope `repo` + `workflow`. |
| `git push` bị reject vì remote ahead | `git pull --rebase origin master` rồi push lại. |
| AWS user không có quyền S3 | Gắn policy `AmazonS3FullAccess` cho IAM user `ai-lab-user`. |
| Không có default VPC → không tạo được EC2 | `aws ec2 create-default-vpc`, sau đó tạo instance `t2.micro`. |
| Service `mlops-serve` trên EC2 lỗi `KeyError: S3_BUCKET` | Sửa file systemd: đặt biến môi trường `S3_BUCKET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` đúng định dạng. |
| MLflow lỗi `ModuleNotFoundError: pkg_resources` trên Python 3.12 | Cố định `setuptools==69.5.1` trong `requirements.txt`. |
| Accuracy < 0.70 với 2.998 mẫu | Bổ sung dữ liệu bằng `add_new_data.py` (Bước 3) để đạt 0.754 và vượt eval gate. |

---

## 5. Kết quả kiểm thử

**GitHub Actions:** Pipeline `MLOps Pipeline` — 4 job đều thành công (Unit Test → Train → Eval → Deploy).

**API trên EC2:**

```text
GET  /health  → {"status":"ok"}
POST /predict → {"prediction":0,"label":"thap"}
```

**Cloud storage (S3):** Dữ liệu DVC trong prefix `dvc/`; model tại `models/latest/model.pkl`.

---

## 6. Tài liệu đính kèm (screenshots)

| File | Nội dung |
|---|---|
| `submission/01_mlflow.png` | MLflow UI — nhiều lần chạy thí nghiệm |
| `submission/02-github-actions.png` | GitHub Actions — 4 jobs màu xanh |
| `submission/04-curl.png` | Kết quả `curl /health` và `/predict` |
| `submission/05-s3-console.png` | AWS S3 bucket — dữ liệu và model |

---

## 7. Kết luận

Lab đã hoàn thành đầy đủ ba bước: thực nghiệm cục bộ với MLflow, pipeline CI/CD tự động trên AWS, và huấn luyện lại khi có dữ liệu mới. Bộ siêu tham số `n_estimators=300`, `max_depth=null` cho kết quả tốt nhất trên tập nhỏ; thêm dữ liệu ở Bước 3 cải thiện rõ rệt accuracy lên 0.754 và cho phép deploy qua eval gate.
