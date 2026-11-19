# Tileset lũy gỗ Cổ Nguyệt Sơn Trại

Bộ v1 dùng ô vuông 48 × 48 px, được lấy mẫu từ các tấm lũy gỗ đã ghép để duyệt.

| Tệp | Nội dung |
| --- | --- |
| [atlas.png](atlas.png) | 30 khung trong một ảnh, gồm 20 ô nền và 10 mảnh ghép trên lớp riêng. |
| [tileset.json](tileset.json) | Tọa độ khung, nhóm biến thể, đi được hay bị chặn, cao độ sàn và hướng lên cầu thang. |
| [preview.png](preview.png) | Bố cục thử 24 × 16 ô, dựng bằng chính các khung trong atlas. |

Mỗi nhóm nền có bốn biến thể dùng chung mép. Nền sân và bùn ở cao độ 0, sàn gỗ ở cao độ 1. Khung ảnh gốc của cầu thang hướng bắc chiếm 2 × 3 ô trong atlas, khung hướng tây chiếm 3 × 2 ô. Trên bản đồ Sơn Trại, hình cầu thang 2 × 2 ô được căn giữa lối đi rộng một ô và dài hai ô. Hai dải ô dọc tay vịn chặn bước và chặn tìm đường. Đầu cao nối sàn gỗ, chân thấp nối sân đá.

Để xuất lại ở thư mục gốc của repo, dùng Node.js và bộ đọc PNG của repo game chính.

```text
node scripts/build-rampart-tiles.cjs <pixel-png.cjs> <tấm-trên-trái.png> <tấm-trên-phải.png> <tấm-dưới-phải.png> <thư-mục-xuất>
```

Manifest lưu tên và mã SHA-256 của ba tấm nguồn. Script kiểm tra mọi mép nền và tọa độ khung khi xuất.

Để đóng gói atlas có sẵn thành ba ảnh mà game dùng, chạy từ thư mục gốc của repo.

```text
node scripts/pack-rampart-tiles.cjs <pixel-png.cjs> docs/tilesets/co-nguyet-rampart-v1 dist/assets/rampart
```

`ground.png` chứa nền sân, đất bùn và sàn gỗ. `forest.png` chứa tán trúc và mép rừng. `rampart.png` chứa cọc, góc nối, chân đỡ và cầu thang.
