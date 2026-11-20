# Mẫu Thủ Thế, Điện Lang Vồ & Đỡ Phản Lực (Godot Thanh Mao)

Gói tài nguyên và cảnh duyệt độc lập trên nhánh `antigravity/godot-guard-sample` (tách từ `82ba3ef`, phục vụ Task `3e602208-22ca-4a42-ab2c-14621b15e3f6` / Issue #2 / PR #9). Toàn bộ tệp đặt trong `godot-combat/assets/guard-review/` và cảnh duyệt riêng `godot-combat/guard_review.tscn`, không sửa `arena.gd`, `battle_rules.gd`, hay `combat_preview.gd`.

---

## 1. Đối chiếu Atlas hiện có ở cỡ chơi (`TILE = 91 × 82`, `HERO span = 112/113`, `WOLF span = 118`)

- **`res://assets/huyen-bao.png`** (`512 × 384`, `8 × 6` ô `64 × 64`, `y1 = 60`):
  - Tư thế đứng sẵn trong trận là `hero_frame = 13` (tấn mã bộ rộng, tay trái đưa ra trước).
  - Các khung `6..13` và `14..18` vốn là chuyển tiếp giữa thế đứng thẳng (`frame 0`) và thế mã bộ (`frame 13`), không có động tác dựng ống tay áo rộng chặn trước ngực và không có phản lực trượt lùi khi Điện Lang lao vào.
- **`res://assets/huyen-bao-combat.png`** (`1024 × 256`, `8 × 2` ô `128 × 128`, `y1 = 120`, lưới macro-pixel `2 × 2` chuẩn `0` mixel):
  - Hàng 0 (`0..7`) là xuất chưởng Nguyệt Quang, Hàng 1 (`8..15`) là trúng đòn ngửa người.
- **`res://assets/dien-lang.png`** (`512 × 512`, `4 × 4` ô `128 × 128`, `y1 = 107`, vẽ tại `wolf_point + Vector2(0, 11)` với `span = 118`, `face = -direction`):
  - Khung `8` (`coil`): Co thấp thân lấy đà (`y0 = 65, y1 = 107`).
  - Khung `9` (`leap`): Vồ trên không há hàm răng (`x1 = 117, y = 48..64`).
  - Khung `10` (`contact`): **Khung chạm của sói** — hai chân trước và nanh táp bổ xuống mục tiêu (`x1 = 117, y = 70..94`).
  - Khung `11` (`recoil/recover`): Thu thân đáp đất trước khi về `frame 0` (`idle`).

---

## 2. Thông số Atlas mới (`res://assets/guard-review/huyen-bao-guard.png`)

- **Tệp trong gói**:
  - `huyen-bao-guard.png`: Atlas PNG trong suốt `1024 × 256` (`8 cột × 2 hàng`, mỗi ô `128 × 128`, lưới macro-pixel `2 × 2` đồng nhất `0` mixel, alpha nhị phân `0 | 255`).
  - `huyen-bao-guard.aseprite`: Nguồn Aseprite `128 × 128` gồm 8 khung, 2 layer (`HuyenBaoGuard`, `GuardWardFX`) và 4 tag (`brace`, `hold`, `impact`, `recover`).
  - `guard-review.json`: Manifest đầy đủ thông số ô, neo chân, hướng, bảng timing `ms`, tọa độ điểm chặn tay áo và khung chạm của sói.
  - `guard-exchange-play-scale.gif` & `guard-comparison-strip.png`: Clip GIF và bảng đối chiếu trước/sau ở đúng cỡ chơi trên nền **Rìa rừng Thanh Mao**.
- **Kích cỡ ô & Điểm neo**:
  - `cellSize`: `[128, 128]` (`cols = 8, rows = 2`).
  - `footAnchor128`: `[64, 120]` (khớp 1:1 với `huyen-bao-combat.png` ở `span = 112`, `pivot = Vector2(-span * 0.5, -span * 0.77)`).
  - `facing`: `"right"` (`+1` khi quay phải về phía sói, `-1` khi quay trái).
  - **Điểm chặn trên tay áo (`sleeveBlockPoint128`)**: `[88, 76]` trong ô `128 × 128` (tương đương `[44, 38]` trên lưới `64 × 64`, hoặc độ lệch màn hình `Vector2(21.0 * direction, -19.7)` tính từ `hero_point` khi vẽ ở `span = 112`).

---

## 3. Bảng Thứ Tự Khung & Timing Chuỗi 4 Nhịp (`930 ms`, Khung chạm tại `520 ms`)

| Nhịp | Khung Hero (`Row 0`) | Khung VFX (`Row 1`) | Khung Điện Lang (`dien-lang.png`) | Bắt đầu (`ms`) | Thời lượng (`ms`) | Mô tả hoạt ảnh |
| --- | --- | --- | --- | --- | --- | --- |
| **1. Thủ thế (`brace`)** | `0` (`brace_start`) | `8` | `0` (`idle`) | `0` | `70` | Khớp 1:1 với `huyen-bao.png` frame `13` (`ready`) để vào thế không giật hình. |
| **1. Thủ thế (`brace`)** | `1` (`brace_sweep`) | `9` | `0` (`idle`) | `70` | `80` | Quét ống tay áo rộng huyền bào lên trước ngực, thu nhẹ mũi chân trước bám đất. |
| **1. Thủ thế (`brace`)** | `2` (`brace_planted`) | `10` | `0` (`idle`) | `150` | `90` | Dựng cẳng tay phải và tà tay áo cong hình chuông che kín ngực/cổ, tay trái đỡ khuỷu, viền nguyên khí ánh vàng tại `[88, 76]`. |
| **2. Sói lấy đà & vồ (`wolf_lunge`)** | `3` (`guard_hold_tense`) | `11` | `8` (`coil`, `240..400 ms`) → `9` (`leap`, `400..520 ms`) | `240` | `280` | Huyền bào hạ trọng tâm `2px` giữ vững thế thủ; Điện Lang lùi `10px` lấy đà (`frame 8`) rồi bật vồ tới trước mặt (`frame 9`). |
| **3. Đỡ phản lực (`block_impact`)** | **`4` (`block_impact_recoil`)** | **`12`** | **`10` (`contact`)** | **`520` (Khung chạm)** | `95` | **Khung chạm (`520 ms`)**: Nanh và móng trước Điện Lang (`frame 10`) đập đúng điểm chặn `[88, 76]`; Huyền bào trượt lùi `4px` (`2` macro-pixel), tà áo sau tung ngược, vòng xung kích hộ thân & bụi gót giày bùng ra. |
| **3. Đỡ phản lực (`block_impact`)** | `5` (`block_counter_push`) | `13` | `11` (`recoil`) | `615` | `115` | Chân sau Huyền bào đạp đất đẩy cẳng tay và tay áo về trước `+4px`, đánh bật Điện Lang dội ngược về ô xuất phát. |
| **4. Thu thế (`recover`)** | `6` (`recover_lower`) | `14` | `11 → 0` | `730` | `100` | Hạ hai ống tay áo rộng xuống ngang hông khi Điện Lang đáp về ô. |
| **4. Thu thế (`recover`)** | `7` (`recover_ready`) | `15` | `0` (`idle`) | `830` | `100` | Trở về đúng tư thế chiến đấu `frame 13` tại `930 ms`, sẵn sàng mở khóa lượt kế tiếp. |

---

## 4. Cảnh Duyệt Độc Lập trong Godot (`res://guard_review.tscn`)

Có thể mở và chạy trực tiếp cảnh duyệt riêng mà không chạm vào `combat_preview.tscn`:

```sh
godot --path godot-combat res://guard_review.tscn
godot --headless --path godot-combat --fixed-fps 60 --script res://tests/guard_review_smoke.gd
```
