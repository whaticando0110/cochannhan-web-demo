# Cổ Chân Nhân · Thềm Hứng Mây

Demo chiến thuật theo lượt trên trình duyệt, lấy bối cảnh Thiên Thê Sơn. Người chơi điều khiển Phương Nguyên và đọc ý định của đối thủ trước khi chọn di chuyển, đánh tay không hoặc dùng Cổ.

![Sàn Thềm Hứng Mây với hai nhân vật, vùng nguy hiểm của Trảm sương và các hành động của Phương Nguyên](docs/arena-preview.png)

## Chơi thử

Cần Node.js 22 trở lên. Trong thư mục repo, chạy:

```sh
npm run preview
```

Mở [http://127.0.0.1:4173](http://127.0.0.1:4173). Ở lượt mở đầu, đối thủ đánh dấu vùng **Trảm sương**. Chọn **Di chuyển** để tìm ô an toàn, hoặc dùng **Bạch Ngọc Cổ** để đỡ đòn và hồi chân nguyên. Hạ sinh lực đối thủ về 0 để thắng.

| Phím | Hành động | Tác dụng trong demo |
| --- | --- | --- |
| `1` | Di chuyển | Đi tối đa 2 ô, vòng qua đá chắn và đối thủ. |
| `2` | Tay không | Đánh ô liền kề và hồi 1 chân nguyên. |
| `3` | Nguyệt Quang Cổ | Tốn 2 chân nguyên để đánh xa tối đa 4 ô. |
| `4` | Bạch Ngọc Cổ | Giảm sát thương trong lượt, hồi 1 chân nguyên. |
| `5` | Sinh Cơ Diệp | Tốn 2 chân nguyên để hồi sinh lực. |

Trên điện thoại, chạm thẻ hành động và ô đích. Trên bàn phím, dùng phím mũi tên và Enter để chọn ô. Nút **Chơi lại** đặt lại toàn bộ trận.

## Mã nguồn và kiểm thử

- `dist/combat.mjs` chứa quy tắc di chuyển, ý định đối thủ và xử lý lượt. Chỉ nhận trạng thái và hành động, nên kiểm thử được ngoài trình duyệt.
- `dist/game.mjs` nối bàn đấu, thao tác và hiệu ứng với bộ xử lý lượt.
- `dist/` là bản web tĩnh tự chứa. Demo chạy hoàn toàn trên trình duyệt, dùng dữ liệu trận riêng và chỉ giữ trạng thái trong phiên.

```sh
npm test
```

Nền Thềm Hứng Mây, gờ đá và atlas nhân vật lấy từ dự án Discord Cổ Chân Nhân ở mốc `cb8b369f`. Quy tắc, chỉ số và đối thủ trong repo này được rút gọn cho trận portfolio.
