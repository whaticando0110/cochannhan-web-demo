# Asset hiệu ứng Cổ bàn giao cho Thú triều Thanh Mao Sơn (Act 1)

Tài liệu kỹ thuật trên nhánh `antigravity/gu-vfx-thu-trieu` phục vụ Issue #2 (`whaticando0110/cochannhan-web-demo`). Phần chuyển động nhân vật Cổ Nguyệt Tĩnh Nghi do Codex phụ trách riêng trên `codex/web-tinh-nghi-motion` (nhánh `antigravity/thu-trieu-assets` tại `18dc497` được giữ nguyên để Codex làm base).

## 1. Huyết Nguyệt (`dist/assets/rampart/huyet-nguyet.png` + `huyet-nguyet.json`)

- **Nguồn chuẩn**: Tách từ `previews/gu-vfx-static-v1/huyet-nguyet/HUYET_NGUYET_VFX_RAW.png` (commit `cb8b369f`, `Reverend-insanity-discord-game`), chỉnh pivot `(40, 38) -> (32, 32)` trong từng ô `64 × 64` không cắt xén, alpha nhị phân `0 | 255`.
- **Kích thước & lưới**: `512 × 320` (`8 cột × 5 hàng`, ô `64 × 64`), cùng quy ước quay phải (`facing: "right"`) với `nguyet-quang.png` và `nguyet-toan.png` (khi bắn về phía tây, `.rampart-moon i` lật `scaleX(-1)`).
- **Bố cục các hàng**:
  - Hàng 0 (`0..7`): `flight` (8 khung, `45 ms/khung`) — tương thích trực tiếp hàng 0 của `nguyet-toan.png`
  - Hàng 1 (`0..3`, `4..7`): `impact_slash` (4 khung, cột `0..3`) + `impact_block` (4 khung, cột `4..7`)
  - Hàng 2 (`0..5`): `cast` (6 khung, tổng `435 ms`)
  - Hàng 3 (`0..5`): `bleed_tick` (6 khung, `85 ms/khung`)
  - Hàng 4 (`0..3`): `blood_trail` (4 khung, `55 ms/khung`)

## 2. Kim Chung Tráo (`dist/assets/rampart/kim-chung-trao.png` + `kim-chung-trao.json`)

- **Nguồn chuẩn**: Tách từ `previews/gu-vfx-static-v1/kim-chung-trao/KIM_CHUNG_TRAO_VFX_RAW.png` (commit `cb8b369f`, `Reverend-insanity-discord-game`), giữ nguyên `sourceSize` `96 × 96` và tâm chân mặt đất `groundPivot: [48, 82]`, alpha nhị phân `0 | 255`.
- **Kích thước & lưới**: `768 × 480` (`8 cột × 5 hàng`, ô `96 × 96`), dùng chung được cho cả nhãn Tam chuyển (khớp tu vi Tam chuyển đỉnh phong của Cổ Nguyệt Tĩnh Nghi) lẫn Tứ chuyển (`supportedRanks: [3, 4]`).
- **Bố cục các hàng**:
  - Hàng 0 (`0..5`): `cast` (6 khung, `420 ms` — vòng ấn vàng và chuông chụp xuống)
  - Hàng 1 (`0..7`): `sustain_back` (8 khung, `640 ms`, lớp `under-actor` vẽ phía sau nhân vật)
  - Hàng 2 (`0..7`): `sustain_front` (8 khung, `640 ms`, lớp `over-actor` vẽ phía trước nhân vật)
  - Hàng 3 (`0..5`): `block` (6 khung, `455 ms` — sóng chuông vàng chấn đỡ đòn)
  - Hàng 4 (`0..5`): `shatter` (6 khung, `495 ms` — chuông nứt vỡ thành mảnh kim quang khi đỡ đòn cao trào)
