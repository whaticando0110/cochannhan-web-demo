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

Atlas V2 do Codex sửa từ bản Antigravity bàn giao ở `18dc497`. Giữ nguyên hàng `idle` và chân dung hiện có. Các tư thế mới dùng ImageGen tham chiếu model gốc, thu về lưới `64 × 64` cùng tỷ lệ, rồi phóng nearest-neighbor `2×`. Có [file Aseprite với 5 tag](art/tinh-nghi-motion.aseprite) khớp atlas và thời lượng trong metadata.

| Hàng | Clip | Số khung | Thời lượng | Chuyển động |
| --- | --- | ---: | ---: | --- |
| 0 | `idle` | 8 | 1400 ms | Giữ nguyên hình và nhịp của bản bàn giao. |
| 1 | `walk` | 4 | 600 ms | Hai nhịp chân chạm đất xen kẽ hai nhịp chân bước qua. |
| 2 | `cast` | 8 | 650 ms | Tụ tay trước ngực, hạ trọng tâm, bước tới phóng cổ, thu tay. |
| 3 | `hit` | 6 | 470 ms | Vai bật lùi, lùi chân ghìm sức, đứng lại. |
| 4 | `guard` | 6 | 680 ms | Dựng chéo cẳng tay ở khung 2, ghìm thế đỡ ở khung 3. |

- Atlas `1024 × 640`, `8 × 5` ô `128 × 128`, alpha `0 | 255`, cạnh dưới bàn chân `y = 121`. Hàng 0 cột 0 trùng ảnh `tinh-nghi-sprite.png`. Lấy số khung và nhịp từ `clips[name].count` và `timesMs`. Dùng `800% 500%` cho `background-size`, tính phần trăm dọc từ `row / 4`.
- Khung tụ `cast[2]` có lòng bàn tay tại `[69, 75]`. Mốc phát vẫn là `cast[4]` tại `330 ms`, lòng bàn tay tại `[104, 66]` hay tọa độ chuẩn hóa `[0.8125, 0.515625]`. Khi lật sprite sang trái, lật cả tọa độ ngang của tay.
- `guard` là tư thế cơ thể dành cho phòng hộ. Tài sản này sẵn sàng để ráp vào cảnh, với chuyển vị, thời điểm va chạm và VFX do cảnh điều khiển.

## 3. Trạng thái Kim Chung Tráo

- Đang **tạm giữ** theo đúng nhịp phối hợp của Issue #2 (*"Mốc phòng hộ chờ chốt bậc Kim Chung Tráo"*) cho tới khi chốt rõ bậc dùng trong phân cảnh lũy tây / Sói Vương.
