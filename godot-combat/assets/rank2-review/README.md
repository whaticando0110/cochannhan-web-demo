# Gói Asset Nhị Chuyển: Nguyệt Mang Cổ & Bạch Ngọc Cổ (Godot Vượt Thanh Mao)

Gói tài nguyên bàn giao riêng trong `godot-combat/assets/rank2-review/` trên nhánh `antigravity/godot-rank2-gu-vfx` cho Issue #2. **Không sửa** `arena.gd`, `combat_preview.gd`, `battle_rules.gd`, `run_flow.gd` hay `run_state.gd`.

---

## 1. Dẫn nguồn tiếng Việt & tách rạch ròi cơ chế demo

- **Nguyên tác tiếng Việt (Chương 98 & Chương 100 — Cổ Chân Nhân):**
  - **Bạch Ngọc Cổ (Nhị chuyển):** Cổ phòng ngự hợp luyện từ *Bạch Thỉ Cổ*, *Ngọc Bì Cổ* và *Dã Trư Nha*. Khi thúc giục tạo lớp ánh ngọc trắng mịn bảo hộ cơ thể, phòng ngự vượt trội hẳn Ngọc Bì Cổ Nhất chuyển.
  - **Nguyệt Mang Cổ (Nhị chuyển):** Hợp luyện từ *Nguyệt Quang Cổ* và *Tiểu Quang Cổ*, chém ra nguyệt nhận ánh trăng lớn và sắc bén hơn hẳn giai đoạn Nhất chuyển.
- **Cơ chế demo tách riêng khỏi nguyên tác:**
  - **Nguyệt Ấn** là trạng thái đánh dấu trên đối thủ dùng riêng trong demo Godot (`battle_rules.gd`), nên biến thể `flight_marked`, `impact_marked` và `mark_emblem` là đề xuất thị giác game để người chơi nhận diện đòn kích phát ấn.

---

## 2. Đánh giá tái sử dụng Bạch Ngọc từ Activity

Đã kiểm tra các tệp sẵn có trong Activity trước khi dựng gói mới:
- `apps/activity-sandbox/public/art/bach-ngoc.png` (`132×138`) + `bach-ngoc.json` + `scripts/aseprite/prod/prod_gu_bach_ngoc.lua`
- `apps/activity-sandbox/public/art/gu-novel-white-jade.png` (`128×128`)

**Kết luận:**
1. **Không dùng thô atlas `bach-ngoc.png` (Phaser packed/trimmed):** 16 khung xếp nén không đều theo tọa độ `spriteSourceSize`, không tương thích trực tiếp với phép cắt lưới đều `Rect2(col * w, row * h, w, h)` của Godot `arena.gd`. Ngoài ra, bảng màu cũ ngả xanh bích (`#d4f6e8 / #84ceb6 / #428672`) trùng tông với **Ngọc Bì Cổ Nhất chuyển**, và các hạt đơn điểm `1px` bị loãng khi phóng trong ô `91×82`.
2. **Không thu nhỏ thô `gu-novel-white-jade.png`:** Bản 128px có 695 màu anti-aliased nên giảm trực tiếp xuống `32×32` sẽ viền mờ.
3. **Phần đã kế thừa & nâng cấp:**
   - Giữ lại **cấu trúc 3 nhịp** đã duyệt từ `prod_gu_bach_ngoc.lua` (*lên lớp tụ ấn → duy trì mảnh → tường cẳng tay va chạm phản chấn*).
   - Kế thừa dáng viên ngọc bầu dục và bảng màu **Dương Chi Bạch Ngọc trắng ngà ấm** (`#fffdf6 / #f4eedc / #d8d1bd / #a69f8d`, viền đá sẫm `#353833`) để tách biệt hoàn toàn khỏi Ngọc Bì Cổ và vẫn nổi rõ trên nền hang đá `stone.png` lẫn nền đất `mulch.png`.

---

## 3. Danh sách tệp bàn giao (`godot-combat/assets/rank2-review/`)

| Tệp | Kích thước / Định dạng | Mô tả |
| --- | --- | --- |
| `nguyet-mang-co.png` | `512 × 320` (`8 × 5` ô `64 × 64`, alpha `0\|255`) | Atlas Nguyệt Mang Cổ 5 hàng (thường + biến thể Nguyệt Ấn). |
| `nguyet-mang-co-icon.png` | `32 × 32` (alpha `0\|255`) | Icon UI Nguyệt Mang Cổ. |
| `nguyet-mang-co.aseprite` | `64 × 64` (`38` khung, `5` tag) | Nguồn Aseprite chỉnh sửa được. |
| `bach-ngoc-co.png` | `768 × 384` (`6 × 3` ô `128 × 128`, alpha `0\|255`) | Atlas Bạch Ngọc Cổ đồng chuẩn điểm neo với `ngoc-bi-co.png`. |
| `bach-ngoc-co-icon.png` | `32 × 32` (alpha `0\|255`) | Icon viên Bạch Ngọc `32 × 32` sắc nét. |
| `bach-ngoc-co.aseprite` | `128 × 128` (`18` khung, `3` tag) | Nguồn Aseprite chỉnh sửa được. |
| `rank2-review.json` | JSON manifest | Timing theo `ms`, bbox, điểm neo, đánh giá Activity. |
| `nguyet-mang-compare-play-scale.gif` | `546 × 328` (ô `91 × 82`) | Clip so sánh Rank 1 Nguyệt Quang vs Rank 2 Nguyệt Mang (thường & Nguyệt Ấn) trên Huyền bào / Áo rêu × Đất / Hang đá. |
| `bach-ngoc-compare-play-scale.gif` | `364 × 328` (ô `91 × 82`) | Clip Bạch Ngọc Cổ (`cast → sustain → impact_deflect`) trên Huyền bào / Áo rêu × Đất / Hang đá. |
| `rank2-review-board.png` | `768 × 592` | Bảng đối chiếu tĩnh tổng hợp Rank 1 vs Rank 2, từng ô atlas và icon `32×32`. |

---

## 4. Cách lấy frame & điểm neo trong Godot (`arena.gd`)

### A. Nguyệt Mang Cổ (`nguyet-mang-co.png`, `cell = 64×64`, `pivot = Vector2(32, 32)`, quay phải `+x`)
Hàng `row` theo trạng thái:
- `row = 0` (`cols 0..7`, `320 ms`): **flight thường** — khi bay trong `cast()`, thay `Rect2(floorf(phase * 7) * 64, 0, 64, 64)` với `projectile_span = 61.0`.
- `row = 1` (`cols 0..7`, `360 ms`): **impact thường** — phát tại điểm trúng trên sói (`contactFrames = [0, 1]`).
- `row = 2` (`cols 0..7`, `320 ms`): **flight_marked (Nguyệt Ấn)** — khi `empowered == true`, lấy `Rect2(floorf(phase * 7) * 64, 128, 64, 64)` với `projectile_span = 73.0`.
- `row = 3` (`cols 0..7`, `440 ms`): **impact_marked (vỡ Nguyệt Ấn)** — phát khi tiêu ấn (`row = 3`, `y = 192`), nổi bật chém chữ X + vòng vỡ vàng-lam.
- `row = 4` (`cols 0..5`, `600 ms` loop): **mark_emblem** — vẽ thay `draw_arc` tại `wolf_point + Vector2(0, -57)` với cỡ hiển thị ~`40..44 px`.

### B. Bạch Ngọc Cổ (`bach-ngoc-co.png`, `cell = 128×128`, `footAnchor128 = [64, 120]`, `impactCenter128 = [86, 74]`)
Dùng cùng helper vẽ nhân vật của `arena.gd` với `span = 112.0` và `pivot = Vector2(-span * 0.5, -span * 0.77)` tại `hero_point` (đặt lật ngang `face` cùng chiều với Huyền bào / Áo rêu):
- `row = 0` (`cols 0..5`, `540 ms`, khóa lớp lúc `245 ms` ở `col = 3`): **cast** — tụ ấn bát giác tại ngực rồi khóa viền ánh ngọc trắng.
- `row = 1` (`cols 0..5`, `660 ms` loop): **sustain** — viền ngọc trắng ngà mảnh ôm vai/tay áo/tà áo cùng 2 tinh thể xoay ngoài thân, không che nội dung Áo rêu hay Huyền bào.
- `row = 2` (`cols 0..5`, `450 ms`, chạm ở `col 0..1`): **impact_deflect** — tường ngọc phản chấn bên cẳng tay phải kèm mảnh ngọc bắn ra khi chặn đòn của Điện Lang.
