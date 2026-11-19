# Cổ Chân Nhân · Demo web

Đi tự do từ **Cổ Nguyệt Sơn Trại** qua đường rừng đến **bãi săn Thanh Mao**. Khi chạm trán sói, bản đồ giữ nguyên vị trí và chuyển sang chiến đấu theo lượt. Hạ sói để tiếp tục đi theo lối mòn phía đông.

Sơn Trại kéo dài theo trục bắc–nam. Khi mở map, bầy sói chạy từ rặng trúc bên trái qua khoảng đất trống tới chân lũy tây.

[Kế hoạch hoàn thiện demo](docs/ke-hoach-demo.md)

Chọn **Khai Khiếu** để thử vượt sông ngầm và đi sâu vào vườn Nguyệt Lan. Kết quả dựa vào độ sâu lớn nhất. Các cụm Hy Vọng Cổ màu vàng hồi sức đi tiếp. [Luật và nguồn truyện](docs/dai-dien-khai-khieu.md)

![Cuộc chạm trán với sói trên cùng bản đồ vừa khám phá](docs/forest-encounter.png)

## Chơi thử

Cần Node.js 22 trở lên. Trong thư mục repo, chạy:

```sh
npm run preview
```

Mở [bản demo local](http://127.0.0.1:4173). Bản đồ có **42 × 26 ô**. Dùng WASD, phím mũi tên hoặc chạm một ô để đi tới đó. Các ô có vật cản chặn đường. Nếu đang đi theo một đường đã chọn, nhân vật dừng ở ô bắt đầu cuộc chạm trán.

Bấm **Shift** một lần để bật chạy khi khám phá, bấm lần nữa để về đi bộ. Nút **Chạy** dưới bản đồ cũng đổi chế độ và trình duyệt ghi nhớ lựa chọn. Huyền bào dùng dáng chạy riêng trên nền phẳng. Trên cầu thang, nhân vật đi từng bước ở lối giữa rộng một ô và trở lại nhịp đã chọn sau khi ra khỏi thang. Mỗi lượt **Chơi lại** chọn biến thể nền theo mã riêng và giữ vị trí các tuyến đường, cọc và bậc thang.

Khi giao chiến, ô đỏ cho biết vùng sói sắp đánh. Mỗi hành động kết thúc lượt và sói phản ứng theo ý định hiển thị. Nếu gục, chọn **Thử lại trận** để trở về lúc sói xuất hiện.

| Phím | Hành động | Tác dụng trong demo |
| --- | --- | --- |
| `1` | Di chuyển | Đi tối đa 2 ô, vòng qua đá chắn và đối thủ. |
| `2` | Tay không | Đánh ô liền kề và hồi 1 chân nguyên. |
| `3` | Nguyệt Quang Cổ | Tốn 2 chân nguyên để đánh xa tối đa 4 ô. |
| `4` | Thủ thế | Giảm sát thương trong lượt, hồi 1 chân nguyên. |

Trong trận, chọn **Di chuyển**, rồi chạm ô sáng hoặc dùng phím mũi tên và Enter. Nút **Chơi lại** đặt lại toàn bộ đoạn thử.

### Đấu nhanh

Mở **Đấu nhanh** để chơi trận thử ban đầu tại Thềm Hứng Mây. Trận này dùng bộ Cổ riêng với Bạch Ngọc Cổ và Sinh Cơ Diệp.

![Trận đấu nhanh tại Thềm Hứng Mây với vùng nguy hiểm của Trảm sương](docs/arena-preview.png)

## Mã nguồn và kiểm thử

- `dist/combat.mjs` chứa quy tắc di chuyển, ý định đối thủ và xử lý lượt. Chỉ nhận trạng thái và hành động, nên kiểm thử được ngoài trình duyệt.
- `dist/world.mjs` định nghĩa địa hình, vùng chạm trán, tìm đường và chuyển chế độ. Cả hai chế độ đọc cùng vị trí và vật cản.
- `dist/expedition.mjs` nối bản đồ và camera với bàn phím, cảm ứng và bộ xử lý lượt. `dist/game.mjs` điều khiển trận Đấu nhanh.
- `dist/assets/rampart/` chứa ba bộ hình 48 × 48 px cho nền, viền rừng và lũy gỗ. Xem cả [atlas nguồn và quy trình đóng gói](docs/tilesets/co-nguyet-rampart-v1).
- `dist/` là bản web tĩnh tự chứa. Demo chạy hoàn toàn trên trình duyệt, dùng dữ liệu trận riêng và chỉ giữ trạng thái trong phiên.

```sh
npm test
```

Đồ họa đường rừng, vật cản và sói lấy từ dự án Discord Cổ Chân Nhân ở mốc `cb8b369f`. Lũy gỗ được ghép từ bộ ô làm theo ảnh Cổ Nguyệt Sơn Trại đã duyệt. Cả hai chế độ dùng **Huyền bào tay rộng** từ bản Activity ở mốc `5738f80f`. Bộ này có khung đứng, thủ, lao tới, bật lùi và né đổi hàng. Khi tung đòn, sprite giữ tư thế sẵn sàng trong lúc game hiện hiệu ứng. Chỉ số được rút gọn cho demo portfolio.
