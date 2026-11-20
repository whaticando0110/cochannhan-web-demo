# Gói Ngọc Bì Cổ (Nhất Chuyển) & Sinh Cơ Diệp cho Godot Vượt Thanh Mao

Gói tài nguyên và cảnh duyệt độc lập trên nhánh `antigravity/godot-training-gu-vfx` (tách từ `380b007`, phục vụ Task `98eb5094-dc3c-43e8-878b-9d45d840d84e` / Issue #2 / PR #9). Toàn bộ tệp đặt trong `godot-combat/assets/gu-review/` và cảnh duyệt riêng `godot-combat/gu_review.tscn`, không sửa `combat_preview.gd`, `run_flow.gd`, `run_state.gd`, hay luật chơi.

---

## 1. Căn cứ nguyên tác & Đối chiếu VFX sẵn có

- **Ngọc Bì Cổ (Nhất chuyển — Chương 98)**: Khác với **Bạch Ngọc Cổ** (Nhị chuyển, lớp vỏ ngọc trắng dày che kín như trong `apps/activity-sandbox/public/art/bach-ngoc.png`), Ngọc Bì Cổ Nhất chuyển tạo thành **một lớp màng ngọc mỏng ánh bích thanh ôm sát da thịt** giúp giảm sát thương và phát sáng gân ngọc tại điểm chịu đòn. Bảng màu lam-ngọc nhạt (`#f0fff8 / #a8f2d8 / #5cc9a8`, viền `#19423a`) được chọn để nổi rõ cả trên trang phục tối màu (**Huyền bào**), trang phục xanh rêu (**Áo rêu**), nền đất nâu lẫn nền hang đá xám.
- **Sinh Cơ Diệp (Cửu Diệp Sinh Cơ Thảo — Chương 102)**: Phiến lá trị thương tiêu hao một lần hái từ Cửu Diệp Sinh Cơ Thảo. Đối chiếu với `apps/activity-sandbox/public/art/sinh-co-diep.png`, bản Godot tối ưu kích thước thành chuỗi trị thương ngắn gọn `680 ms`, giữ thoáng vùng đầu/mặt và đi kèm icon vật phẩm `32 × 32` sắc nét.

---

## 2. Bộ 1: Ngọc Bì Cổ (`ngoc-bi-co.png` + `ngoc-bi-co-icon.png`)

- **Atlas chính**: `res://assets/gu-review/ngoc-bi-co.png` — `768 × 384` (`6 cột × 3 hàng`, ô `128 × 128`, lưới macro-pixel `2 × 2` chuẩn `0` mixel, alpha nhị phân `0 | 255`).
- **Nguồn chỉnh sửa**: `res://assets/gu-review/ngoc-bi-co.aseprite` (`128 × 128`, `18` khung, `1` layer `NgocBiCo`, `3` tag `cast`, `sustain`, `impact_flash`).
- **Icon UI**: `res://assets/gu-review/ngoc-bi-co-icon.png` (`32 × 32`, alpha `0 | 255`).
- **Điểm neo & Hiển thị Godot**: `footAnchor128: [64, 120]`, `centerAnchor128: [64, 76]`, `impactCenter128: [84, 74]`, vẽ ở `span = 112`, `pivot = Vector2(-span * 0.5, -span * 0.77)`.

| Hàng (`clip`) | Số khung | Tổng thời lượng (`ms`) | Thời lượng từng khung (`ms`) | Ghi chú đồng bộ |
| --- | --- | --- | --- | --- |
| **Hàng 0 (`cast`)** | `6` (`0..5`) | `510 ms` | `[80, 80, 90, 90, 85, 85]` | Tụ hạt ngọc tại đan điền rồi phủ màng ngọc mỏng ôm vai/cánh tay/tà áo; khóa lớp ngọc ở `250 ms` (khung `3`). |
| **Hàng 1 (`sustain`)** | `6` (`6..11`) | `660 ms` (`loop`) | `[110, 110, 110, 110, 110, 110]` | Lớp màng ngọc mỏng rung sáng nhẹ dọc viền vai, tay áo, tà áo, giữ rõ 100% nhân vật bên dưới. |
| **Hàng 2 (`impact_flash`)** | `6` (`12..17`) | `460 ms` | `[50, 65, 80, 85, 90, 90]` | **Lóe sáng đúng lúc chịu đòn**: Khung `0..1` (`0..115 ms`) bùng chớp ngọc-bạch & tia va chạm ngay tại `impactCenter128 = [84, 74]`, sau đó tản tia ngọc nhẹ. |

---

## 3. Bộ 2: Sinh Cơ Diệp (`sinh-co-diep.png` + `sinh-co-diep-icon.png`)

- **Atlas chính**: `res://assets/gu-review/sinh-co-diep.png` — `1024 × 128` (`8 cột × 1 hàng`, ô `128 × 128`, lưới macro-pixel `2 × 2` chuẩn `0` mixel, alpha nhị phân `0 | 255`).
- **Nguồn chỉnh sửa**: `res://assets/gu-review/sinh-co-diep.aseprite` (`128 × 128`, `8` khung, `1` layer `SinhCoDiep`, `1` tag `heal`).
- **Icon vật phẩm UI**: `res://assets/gu-review/sinh-co-diep-icon.png` (`32 × 32`, alpha `0 | 255`) — lá xanh ngọc nổi gân vàng, cuống lá rõ và 2 hạt sương sinh cơ.
- **Điểm neo & Hiển thị Godot**: `footAnchor128: [64, 120]`, `chestAnchor128: [64, 74]`, vẽ ở `span = 112`, `pivot = Vector2(-span * 0.5, -span * 0.77)`.

| Hàng (`clip`) | Số khung | Tổng thời lượng (`ms`) | Thời lượng từng khung (`ms`) | Mốc đỉnh trị thương |
| --- | --- | --- | --- | --- |
| **Hàng 0 (`heal`)** | `8` (`0..7`) | `680 ms` | `[75, 80, 85, 95, 95, 90, 80, 80]` | **`healPeakMs = 240 ms` (khung `3`)**: Lá Sinh Cơ hiện trước ngực → hai dải khí sinh cơ xanh vàng cuộn xoắn hai bên sườn cùng lá nhỏ & vòng chân → tan hạt sương trên vai. |

---

## 4. Clip đối chiếu cỡ chơi & Cảnh duyệt Godot riêng

- **Clip & Bảng đối chiếu** (`TILE = 91 × 82`, `Huyền bào span = 113`, `Áo rêu span = 109`, `VFX span = 112`, đủ 4 góc phần tư **Huyền bào/Áo rêu × Nền đất/Nền hang đá**):
  - `ngoc-bi-co-play-scale.gif`
  - `sinh-co-diep-play-scale.gif`
  - `gu-review-board.png`
- **Cảnh duyệt Godot riêng (`res://gu_review.tscn`)**:

```sh
godot --path godot-combat res://gu_review.tscn
godot --headless --path godot-combat --fixed-fps 60 --script res://tests/gu_review_smoke.gd
```
