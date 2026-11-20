# Gói Hệ Ẩn (Ẩn Thạch / Ẩn Lân Cổ) & Hẻm Đá Phục Kích (Godot Vượt Thanh Mao)

Gói tài nguyên bàn giao riêng trong `godot-combat/assets/ambush-veil-review/` trên nhánh `antigravity/godot-ambush-veil-art` cho Issue #2. **Không sửa** `arena.gd`, `combat_preview.gd`, `battle_rules.gd`, `run_flow.gd` hay `run_state.gd`.

---

## 1. Dẫn nguồn Chương 116, 121 & 130 + Tách cơ chế demo

- **Nguyên tác tiếng Việt (Chương 116 / Chương 121 / Chương 130 — Cổ Chân Nhân):**
  - **Ẩn Thạch Cổ (Nhất chuyển):** Chỉ có thể ẩn giấu thân thể cổ sư chứ **không che giấu kèm y phục**, khiến quần áo vẫn lộ ra nếu mặc đồ.
  - **Ẩn Lân Cổ (Nhị chuyển):** Hợp luyện từ *Ẩn Thạch Cổ* và *Ngư Lân Cổ*, tạo gợn ánh nước che giấu trọn vẹn cả thân thể lẫn y phục.
- **Cơ chế demo tách riêng khỏi nguyên tác:**
  - Hiệu ứng Điện Lang thường bị lạc khóa mục tiêu (biểu tượng `?` / `wolf_lost_target` và dấu ô cũ `stealth_lost_tile`) cùng địa hình Hẻm Đá Phục Kích với mảng nứt đi được và dấu báo đá rơi màu hổ phách là cơ chế chiến đấu demo.

---

## 2. Báo cáo tái sử dụng atlas Ẩn Lân từ Activity

Đã kiểm tra `apps/activity-sandbox/public/art/an-lan.png` (`130×92`) + `an-lan.json` + `gu-novel-stealth-scales.png`:
- **Kết luận: TÁI SỬ DỤNG TRỰC TIẾP (lossless) toàn bộ 16 khung hiệu ứng** trong `an-lan.png` (`cast-0..3`, `shimmer-0..7`, `uncloak-0..3`) vì ảnh gốc đã dùng binary alpha `0|255` và bảng 5 màu cá nước rất sạch.
- Đã giải nén từ `spriteSourceSize` sang lưới đều `1024×512` (`8×4` ô `128×128` @ `2×2` macro-pixel), dịch trục dọc `fx_foot (32,50) → footAnchor128 [64, 120]` (`+10px` logic) và bổ sung Hàng 3 (`wolf_lost_target` `cols 0..3`).
- Icon `an-lan-co-icon.png` (`32×32`) kế thừa dáng cá vảy đá từ `gu-novel-stealth-scales.png`.

---

## 3. Tệp bàn giao & quy chuẩn hiển thị (`godot-combat/assets/ambush-veil-review/`)

| Tệp | Kích thước | Mô tả |
| --- | --- | --- |
| `an-lan-co.png` / `-icon.png` / `.aseprite` | `1024×512` (`8×4 @ 128×128`), icon `32×32` | Hàng `0..2` tái dùng trực tiếp từ Activity `an-lan.png`; Hàng `3` `cols 0..3` là dấu `?` lạc mục tiêu trên Điện Lang. |
| `an-thach-co.png` / `-icon.png` / `.aseprite` | `768×384` (`6×3 @ 128×128`), icon `32×32` | Nhất chuyển: thân mờ nhưng cố ý để lộ nét viền y phục & đai lưng. |
| `ambush-canyon-tiles.png` | `364×164` (`4×2 @ 91×82`) | Hàng 0: 4 nền đá phiến; Hàng 1: `(0..1,1)` mảng nứt đi được, `(2..3,1)` đá chẻ thấp chắn đường. |
| `rockfall-telegraph.png` / `.aseprite` | `364×164` (`4×2 @ 91×82`) | Báo đá rơi **màu hổ phách** (khung góc + mũi tên rơi dọc `v` + bóng tròn) tách biệt hoàn toàn gạch chéo đỏ đòn vồ `(0,1)`. |
| `mockup-hem-da-phuc-kich.png` | `803×477` (lưới `8×5 @ 91×82`) | Ảnh duyệt Hẻm Đá Phục Kích có đá chẻ thấp, mảng nứt đi được, đá rơi hổ phách vs đòn vồ đỏ, Ẩn Thạch vs Ẩn Lân & sói lạc mục tiêu `?`. |
| `stealth-compare-play-scale.gif` | `546×328` | Clip so sánh trực tiếp `Ẩn Thạch lộ áo` vs `Ẩn Lân + Điện Lang lạc mục tiêu`. |
| `ambush-veil-review-board.png` | `800×640` | Bảng đối chiếu Activity `an-lan.png` → Godot, icon 32px, atlas & ô địa hình. |
