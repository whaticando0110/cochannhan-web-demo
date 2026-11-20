# Gói Đồ Họa Tửu Trùng (Nhất/Nhị chuyển) & Bãi Đá Suối Sấm (Godot Vượt Thanh Mao)

Gói tài nguyên bàn giao riêng trong `godot-combat/assets/thunder-ford-review/` trên nhánh `antigravity/godot-thunder-ford-art` cho Issue #2. **Không sửa** `arena.gd`, `combat_preview.gd`, `battle_rules.gd`, `run_flow.gd` hay `run_state.gd`.

---

## 1. Dẫn nguồn tiếng Việt & tách rạch ròi cơ chế demo

- **Nguyên tác tiếng Việt (Chương 121 & Chương 225 — Cổ Chân Nhân):**
  - **Tửu Trùng (Nhất chuyển):** Hình dáng giống con tằm béo tròn tỏa ánh trắng dịu, dùng để lọc tạp chất và tinh luyện chân nguyên Thanh Đồng.
  - **Tứ Vị Tửu Trùng (Nhị chuyển):** Hợp luyện từ hai Tửu Trùng cùng bốn loại rượu *Chua, Ngọt, Đắng, Cay*, giúp tinh luyện chân nguyên Xích Thiết Nhị chuyển.
- **Cơ chế demo tách riêng khỏi nguyên tác:**
  - Hệ thống cộng dồn `stack_1` / `stack_2` tăng sát thương cho cú Tay không (`BREW_STRIKE_BONUS` trong `gu_catalog.gd`) và đòn **Dẫn lôi qua nước** trên Bãi Đá Suối Sấm (`THUNDER_FORD`, các ô `rules.water`) là cơ chế game demo để làm nổi bật nhịp dùng Tửu Trùng và địa hình dòng nước nông đi được.

---

## 2. Danh sách tệp bàn giao (`godot-combat/assets/thunder-ford-review/`)

| Tệp | Kích thước | Vai trò |
| --- | --- | --- |
| `tuu-trung-co.png` / `-icon.png` / `.aseprite` | `768×256` (`6×2 @ 128×128`), icon `32×32` | Tửu Trùng Nhất chuyển: `refine_cast` (hồi chân nguyên) & `qi_pulse` loop. |
| `tu-vi-tuu-trung.png` / `-icon.png` / `.aseprite` | `768×384` (`6×3 @ 128×128`), icon `32×32` | Tứ Vị Tửu Trùng Nhị chuyển: `refine_cast`, `stack_1` và `stack_2` (4 hạt vị + luồng tay Xích Thiết). |
| `wet-stone-tiles.png` | `364×164` (`4×2 @ 91×82`) | 4 ô đá ướt đi được, 2 tảng đá ướt chắn đường, 2 nền sỏi suối nông. |
| `water-mask-16.png` / `.aseprite` | `364×328` (`4×4 @ 91×82`, `16` ô) | Lớp nối dòng nước nông theo mask 4 cạnh (`N=1, E=2, S=4, W=8`). |
| `water-electric-telegraph.png` / `.aseprite` | `364×164` (`4×2 @ 91×82`) | Lớp báo trước điện lan theo nước, giữ trống tâm ô để nhân vật & ô dễ đọc. |
| `mockup-bai-da-suoi-sam.png` | `803×477` (lưới `8×5 @ 91×82`) | Ảnh duyệt trực tiếp Bãi Đá Suối Sấm (`water=[18,19,20,21,26,27]`, `rocks=[5,11,28,35]`). |
| `tuu-trung-compare-play-scale.gif` | `546×328` | Clip so sánh `Tửu Trùng R1` vs `Tứ Vị R2 (1 stack vs 2 stack)` trên Huyền bào / Áo rêu. |
| `thunder-ford-review-board.png` | `800×640` | Bảng tổng hợp 16 mask nước, đá ướt, báo điện lan, 2 atlas Tửu Trùng và icon 32px. |

---

## 3. Cách lấy frame & nối mask nước trong `arena.gd`

1. **Tửu Trùng / Tứ Vị Tửu Trùng:** Vẽ tại `hero_point` với `span = 112.0`, `pivot = Vector2(-span * 0.5, -span * 0.77)`, `cell = 128×128`:
   - `tuu-trung-co.png`: `row = 0` (`refine_cast`, chạm hồi CN ở `col 3 @ 255 ms`), `row = 1` (`qi_pulse`).
   - `tu-vi-tuu-trung.png`: `row = 0` (`refine_cast`), `row = 1` (`stack_1`), `row = 2` (`stack_2` — khác biệt rõ khi có 2 cộng dồn).
2. **Mask 4 cạnh cho dòng nước nông (`water-mask-16.png`):**
   - Với mỗi `cell in rules.water`: tính `mask = (has_n ? 1 : 0) | (has_e ? 2 : 0) | (has_s ? 4 : 0) | (has_w ? 8 : 0)`.
   - Cắt ô `Rect2((mask % 4) * 91, (mask / 4) * 82, 91, 82)` vẽ phủ lên nền `shallow_ford` (`row 1, col 2..3`).
3. **Báo trước Dẫn lôi qua nước (`water-electric-telegraph.png`):**
   - Tách thành lớp overlay riêng trên nước & dưới nhân vật: `(0, 0)` ô sát Điện Lang phát lôi, `(1, 0)` lan ngang, `(2, 0)` lan dọc, `(3, 0)` ngã ba/ngã tư, `(0, 1)` khung nhấp nháy luân phiên.
