# Asset bàn giao cho Thú triều Thanh Mao Sơn (Act 1)

Tài liệu kỹ thuật trên nhánh `antigravity/thu-trieu-assets` phục vụ Issue #2 (`whaticando0110/cochannhan-web-demo`).

## 1. Huyết Nguyệt (`dist/assets/rampart/huyet-nguyet.png` + `huyet-nguyet.json`)

- **Nguồn chuẩn**: Tách từ `previews/gu-vfx-static-v1/huyet-nguyet/HUYET_NGUYET_VFX_RAW.png` (commit `cb8b369f`, `Reverend-insanity-discord-game`), chỉnh pivot `(40, 38) -> (32, 32)` trong từng ô `64 × 64` không cắt xén, alpha nhị phân `0 | 255`.
- **Kích thước & lưới**: `512 × 320` (`8 cột × 5 hàng`, ô `64 × 64`), cùng quy ước quay phải (`facing: "right"`) với `nguyet-quang.png` và `nguyet-toan.png` (khi bắn về phía tây, `.rampart-moon i` lật `scaleX(-1)`).
- **Bố cục các hàng**:
  - Hàng 0 (`0..7`): `flight` (8 khung, `45 ms/khung`) — tương thích trực tiếp hàng 0 của `nguyet-toan.png`
  - Hàng 1 (`0..3`, `4..7`): `impact_slash` (4 khung, cột `0..3`) + `impact_block` (4 khung, cột `4..7`)
  - Hàng 2 (`0..5`): `cast` (6 khung, tổng `435 ms`)
  - Hàng 3 (`0..5`): `bleed_tick` (6 khung, `85 ms/khung`)
  - Hàng 4 (`0..3`): `blood_trail` (4 khung, `55 ms/khung`)

## 2. Chuyển động Cổ Nguyệt Tĩnh Nghi (`dist/assets/rampart/tinh-nghi-motion.png` + `tinh-nghi.json`)

- **Bảo toàn tạo hình gốc**: Dựng trên lưới logic `64 × 64` và phóng `2×` nearest-neighbor thành `128 × 128` (`1024 × 512`, `8 cột × 4 hàng`), giữ nguyên ô `[0,0]` khớp 1:1 với `tinh-nghi-sprite.png` (búi tóc, trâm gỗ, lọn tóc bạc, cổ áo kem, bào xanh thông và dải thắt lưng nâu đất, đường chân cố định `y = 121`).
- **Bố cục các hàng**:
  - Hàng 0: `idle` (`8` khung, `1400 ms`)
  - Hàng 1: `walk` (`8` khung, `640 ms`)
  - Hàng 2: `cast` (`8` khung, `610 ms`, thả chiêu tại khung `4` ở `330 ms`; tập con 4 pose cho `rampart-defense`: `[0, 2, 4, 6]`)
  - Hàng 3: `hit` (`8` khung, `420 ms`, thủ thế / giật lùi và hồi tư thế)
- **Tọa độ lòng bàn tay (thang `128 px`)**:
  - Tụ khí (`cast[2]`): `[72.5, 69.5]`
  - Xuất chưởng (`cast[4]`): `[96.1, 69.3]` (`[0.7508, 0.5414]` chuẩn hóa theo ô)

## 3. Trạng thái Kim Chung Tráo

- Đang **tạm giữ** theo đúng nhịp phối hợp của Issue #2 (*"Mốc phòng hộ chờ chốt bậc Kim Chung Tráo"*) cho tới khi chốt rõ bậc dùng trong phân cảnh lũy tây / Sói Vương.
