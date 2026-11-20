# Gói Nét Viền Vách Che & Báo Đòn Theo Hàng (Godot Vượt Thanh Mao)

Gói mockup và asset nguồn trên nhánh `antigravity/godot-cover-and-charge-art` (tách từ `c9a6c86`, phục vụ Task `fecd553d-c4d3-45d1-bf97-710d57060a21` / Issue #2). Toàn bộ tệp nằm gọn trong `godot-combat/assets/terrain-telegraphs-review/`, **không sửa** `arena.gd`, `combat_preview.gd`, `battle_rules.gd`, hay `run_state.gd`.

---

## 1. Danh sách tệp bàn giao (`godot-combat/assets/terrain-telegraphs-review/`)

| Tệp | Kích thước | Vai trò |
| --- | --- | --- |
| `terrain-telegraphs.png` | `364 × 328` (`4 × 4` ô `91 × 82`) | Atlas PNG lớp phủ từng ô khớp 1:1 với `TILE := Vector2(91, 82)` trong `arena.gd`. |
| `terrain-telegraphs.aseprite` | `91 × 82` (`16` khung, `4` tag) | Nguồn Aseprite chỉnh sửa được (`cover`, `elite_charge`, `boss_sweep`, `reference`). |
| `terrain-telegraphs.json` | JSON manifest | Tọa độ UV từng ô, thứ tự vẽ và quy tắc bỏ qua ô đá. |
| `telegraph-legend-strip.png` | `364 × 328` | Bảng đối chiếu cả 16 ô trên nền đất sẫm (`mulch.png`) và nền hang (`stone.png`). |
| `mockup-1-khe-da-cover.png` | `803 × 477` (`8 × 5` ô) | Mockup **Khe đá Hoang Nha** (`rooms[0] = [4, 11, 25, 30]`): viền vách che, đường bắn Nguyệt Quang đứt đoạn và dấu dừng trên đá `D2`. |
| `mockup-2-loi-san-tinh-anh-charge.png` | `803 × 477` (`8 × 5` ô) | Mockup **Lối săn tinh anh** (`rooms[0] = [5, 12, 26, 36]`): báo đòn lao hàng `2` từ `G2` (`<<<`), bỏ qua ô đá `E2 (12)`, giữ rõ Áo rêu tại `C2`. |
| `mockup-3-hang-cuong-dien-lang-sweep.png` | `803 × 477` (`8 × 5` ô) | Mockup **Hang Cuồng Điện Lang** (`rooms[0] = [2, 11, 28, 35]`): Quét hành lang nhấn mạnh đỏ-lam lôi điện trên hàng `3`, giữ rõ Huyền bào và ô đá. |

---

## 2. Bố cục 16 ô trong `terrain-telegraphs.png` (`4 × 4` ô `91 × 82`)

- **Hàng 0 — Khe đá Hoang Nha (Vách che & Điểm dừng đường bắn)**:
  - `(0, 0) cover_tile_rim`: Khung góc kép màu đá khoáng lam-xám ôm viền mọi ô có đá chặn đường đi (`cell in rules.rocks`).
  - `(1, 0) cover_tile_targeted`: Khung viền nhấn hổ phách-vàng khi đường ngắm Nguyệt Quang của người chơi bị vách đá này chặn.
  - `(2, 0) shot_line_blocked`: Vạch ngắm đứt đoạn lam nhạt cho các ô trống nằm giữa người chơi và viên đá chắn.
  - `(3, 0) shot_stop_marker`: Thanh chắn đứng + dấu **`×` vàng sáng** ở mép đối diện tia bắn báo hiệu đạn Nguyệt Quang dừng lại trước đá (lật ngang `flip_h` nếu bắn từ phải sang trái).
- **Hàng 1 — Lối săn tinh anh (Đòn lao khóa cả một hàng)**:
  - Họa tiết **thanh ray tốc độ ngang + mũi tên chỉ hướng `<<<`** màu cam-hổ phách, hoàn toàn khác họa tiết gạch chéo của đòn vồ vùng; giữa ô giữ độ trong nhẹ (`alpha ~ 15%`) để không che nhân vật. Nếu sói lao sang phải (`dx > 0`), chỉ cần lật ngang vùng vẽ `src_rect` hoặc `scale.x = -1`.
  - `(0, 1) charge_lane_origin`: Ô xuất phát ngay trước mặt Điện Lang tinh anh.
  - `(1, 1) charge_lane_mid`: Ô giữa hành lang (mũi tên né lên mép trên/dưới, chừa trống vùng thân Áo rêu / Huyền bào ở tâm ô).
  - `(2, 1) charge_lane_end`: Ô đầu mút cuối hàng có thanh chặn cuối đường lao.
  - `(3, 1) charge_lane_rock_skip`: Tùy chọn chỉ vẽ vài vạch nối mờ sát mép ngoài khi đòn lao xuyên qua hàng có chứa ô đá (`bỏ qua ô đá`), **tuyệt đối không tô nền đỏ/cam đè lên tảng đá**.
- **Hàng 2 — Hang Cuồng Điện Lang (Quét hành lang — Phiên bản nhấn mạnh của Trùm)**:
  - Dùng **cùng ngôn ngữ ray ngang + mũi tên `<<<`** như Hàng 1 để người chơi nhận ra ngay đòn theo hàng, nhưng nâng cấp thành **ray kép đỏ son (`#ff6048`) + tia lôi điện xanh lam (`#88ecff`)** và mũi tên kép vàng sáng; lõi ô vẫn giữ độ trong nhẹ (`alpha <= 17%`) để đá nền hang (`stone.png`) và Huyền bào / Áo rêu luôn đọc rõ.
  - `(0, 2) boss_sweep_origin`, `(1, 2) boss_sweep_mid`, `(2, 2) boss_sweep_end`, `(3, 2) boss_sweep_badge` (ký hiệu tia sét góc trên-trái cho ô khởi phát).
- **Hàng 3 — Đối chiếu & Trạng thái kết hợp**:
  - `(0, 3) pounce_diagonal_ref`: Ô gạch chéo đòn vồ chuẩn `arena.gd` dùng đối chiếu độ khác biệt thị giác.
  - `(1, 3) safe_dodge_cell`: Ô né an toàn xanh lục kèm hình thoi giữa ô.
  - `(2, 3) charge_reachable_amber`: Ô nằm trong tầm đi được nhưng nằm trên đường lao (nền báo đòn theo hàng + hình thoi hổ phách ở giữa).
  - `(3, 3) cover_safe_shelter`: Khung góc lam dịu đánh dấu ô nấp ngay sau lưng vách đá chắn.

---

## 3. Hướng dẫn phủ từng ô trong `arena.gd` (`paint_tiles()`, `ORIGIN = (39, 35)`, `TILE = (91, 82)`)

Khi tích hợp vào `paint_tiles()` cho từng `cell` (`0..39`), vẽ tuần tự theo đúng 8 lớp từ dưới lên trên:

1. **Nền đất (`TRAIL` / `MULCH` / `STONE`)** theo `room`.
2. **Viền lưới mặc định** (`Color("#a0ad793b")`).
3. **Viền vách che (`underRock`)**: nếu `cell in rules.rocks`, vẽ `cover_tile_targeted` `(1, 0)` nếu ô đá này đang chặn đường bắn ngắm tới mục tiêu, ngược lại vẽ `cover_tile_rim` `(0, 0)`.
4. **Sprite đá (`ROCK = rock-ridge.png`)**: vẽ `draw_texture_rect(ROCK, ...)` đè lên trên khung vách che để khung ôm lấy chân đá gọn gàng.
5. **Báo đòn theo hàng (`bỏ qua ô đá`)**:
   - Với **Vồ vùng (`pounce`)**: giữ họa tiết gạch chéo chuẩn (`diagonal striped`).
   - Với **Lao một hàng của Tinh anh (`charge`)** hoặc **Quét hành lang của Cuồng Điện Lang (`sweep`)**:
     - Nếu `cell in rules.rocks`: **KHÔNG** tô ô nguy hiểm lên đá; chỉ giữ `cover_tile_rim` (có thể thêm `charge_lane_rock_skip` `(3, 1)` ở mép trên/dưới nếu muốn nối mạch thị giác).
     - Nếu ô trống thuộc hàng bị khóa: chọn `_origin` ở ô sát trước mặt quái, `_mid` cho các ô giữa (hoặc `charge_reachable_amber` `(2, 3)` nếu đang trong chế độ chọn ô đi và ô đó đi tới được), `_end` ở ô cuối hàng; đặt hướng lật theo chiều lao của sói. Với **Quét hành lang** của Trùm, vẽ thêm `boss_sweep_badge` `(3, 2)` ở ô khởi phát sát trước mặt Cuồng Điện Lang.
6. **Đường bắn bị chặn & Dấu dừng (Khe đá)**: vẽ `shot_line_blocked` `(2, 0)` trên các ô giữa người chơi và đá chắn; vẽ `shot_stop_marker` `(3, 0)` trên mặt đối diện của ô đá chặn đầu tiên (`cover_tile_targeted` đã có ở bước 3).
7. **Ô né an toàn (`safe_dodge_cell`) & ô nấp (`cover_safe_shelter`)** khi đang ở bước chọn ô di chuyển (`selecting`).
8. **Vòng chân (`actor_ring`) → Nhân vật / Điện Lang / Cuồng Điện Lang** luôn vẽ sau cùng để không bao giờ bị lớp phủ che khuất.
