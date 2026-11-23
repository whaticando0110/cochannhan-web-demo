# Kế hoạch roguelike Godot · Vượt Thanh Mao

Ba trận của chương đầu luyện ba kỹ năng theo thứ tự. Đọc vùng báo đòn, tận dụng địa hình, rồi quản lý chân nguyên trước trùm. Đợt đầu dùng hai tuyến đã có để thử địa hình và các kiểu dùng Cổ trước khi mở chương kế.

| Màn | Thử thách và quyết định | Cổ hoặc vật phẩm xuất hiện |
| --- | --- | --- |
| Đại điển Khai Khiếu | Đi qua sông và biển Nguyệt Lan, nhận tư chất và sức chứa chân nguyên. Sau khi gục có thể giữ kết quả cũ để vào lượt mới. | Hy Vọng Cổ xuất hiện trong nghi lễ. Nguyệt Quang là Cổ đánh đầu tiên sau Đại điển. |
| Rìa rừng Thanh Mao | Học né vùng vồ, đánh kề, thủ thế để hồi chân nguyên. Thắng trận chọn tuyến và cân nhắc hồi sức hay lấy thêm cách đánh. | Nguyệt Quang có từ đầu. **Ngọc Bì Cổ** là một lựa chọn thưởng trước màn hai. |
| Khe đá Hoang Nha | Tìm góc bắn vì vách đá chặn Nguyệt Quang. Ba bố cục đặt vách ở ba vị trí khác nhau trên đường bắn ban đầu. | Chọn một lá **Sinh Cơ Diệp** mang vào hang hoặc chọn phần thưởng hồi phục giữa màn. |
| Lối săn tinh anh | Tinh anh luân phiên vồ vùng quanh mục tiêu và lao một hàng. Có lượt đổi vị trí giữa hai đòn nặng. | Mở rộng Nguyên Hải nằm trong nhóm thưởng riêng của tuyến. |
| Điểm nghỉ trước hang | Chọn hồi tối đa 8 sinh lực, hồi 1 chân nguyên hoặc đi tiếp. Mỗi lượt chơi chỉ chọn một lần, có xem trước chỉ số. | Sinh Cơ Diệp dùng trong trận. Ngọc Bì Cổ giữ quyền sử dụng qua các màn, lớp ngọc hết khi chuyển trận. |
| Hang Cuồng Điện Lang | Vồ vùng và quét hành lang dùng dấu khác nhau. Trùm hồi thế sau mỗi đòn nặng. Dưới nửa sinh lực, nó đổi thứ tự đòn và có thể ra đòn nặng ngay khi hết hồi thế. | Màn kết quả ghi đường đi, chiến lợi phẩm và tài nguyên còn lại. |
| Sườn đá Mù Sương | Màn đầu Nhị chuyển có ba bố cục. Điện Lang phóng lôi khóa một ô khi có đường ngắm, rồi hồi thế một lượt. Vách đá chặn đòn tầm xa của hai bên. | Chọn **Nguyệt Mang Cổ**, **Bạch Ngọc Cổ** hoặc **Tứ Vị Tửu Trùng** và ghép với một Cổ Nhất chuyển. Hai Cổ cùng hệ mở hiệu ứng bộ. |
| Bãi Đá Suối Sấm | Vào sau Sườn đá Mù Sương. Điện Lang dẫn lôi luân phiên nhiễm điện vùng nước nông theo bố cục và bắn Hồ quang vào một ô. Mỗi đòn lôi có một lượt hồi thế. Vách đá chặn Hồ quang. | Điểm nghỉ cho hồi tối đa 20 sinh lực và 3 chân nguyên, giữ số lá còn lại và cho đổi bộ. |
| Hẻm Đá Phục Kích | Vào sau Suối Sấm. Điện Lang vồ vào vùng quanh mục tiêu khi có đường ngắm rồi chuyển sang đòn làm đá rơi trên các ô nứt. Hai đòn có một lượt hồi thế. Ô nứt đi được, vách đá chặn đi và bắn. | Điểm nghỉ hồi tối đa 22 sinh lực và 3 chân nguyên, giữ số lá còn lại và cho đổi một trong 16 bộ. |

## Luật để thử

- Trong lượt chơi, giữ **hai khe Cổ**, gồm một khe công và một khe tùy chọn cho bản cân bằng đầu. Có một khe vật phẩm tiêu hao. Thủ thế, di chuyển và tay không là hành động cơ bản.
- Đề xuất **Ngọc Bì** tốn 1 chân nguyên, dùng một hành động để chặn tối đa 5 sát thương của đòn kế tiếp trong hai lượt. Tác dụng còn lại hiện rõ trên HUD. Nếu vừa thủ thế vừa có lớp ngọc, áp dụng thủ thế trước rồi trừ lớp ngọc, mỗi bước hiển thị trong phần xem trước.
- Đề xuất **Sinh Cơ Diệp** hồi 12 sinh lực tối đa đến trần và tiêu hao lá khi dùng. Dược thảo hồi giữa màn, còn lá để dành cho lúc nước sôi lửa bỏng trong trận. Tính lượng hồi và đòn đáp trả trên cùng phần xem trước.
- Cảnh giới mở cùng chương, tư chất quyết định dung lượng chân nguyên. Sau khi hồi sinh, trang bị, vật phẩm và hiệu ứng của lượt cũ được đặt lại. Bỏ qua Khai Khiếu lấy lại hồ sơ nhân vật và tư chất trước đó.
- Nền, ô chặn, đòn trùm và thưởng đã chọn cần khôi phục đúng sau khi tải lại. Mỗi bản đồ phải có đường đi hợp lệ và ít nhất một cách tránh đòn được báo. Kiểm Đinh đẳng với 0 chân nguyên tại màn hai, cả khi chọn hồi phục lẫn lấy Cổ.

Các con số, cách nhận đồ và hành vi địch ở trên là thiết kế game đề xuất. Trong truyện, Ngọc Bì là Cổ phòng ngự Nhất chuyển, Bạch Ngọc và Nguyệt Mang là Nhị chuyển, còn Sinh Cơ Diệp là lá trị thương do Cửu Diệp Sinh Cơ Thảo sinh ra. Địa Thính Nhục Nhĩ Thảo dùng để nghe động tĩnh. [Chương 98](https://truyenfull.live/co-chan-nhan/chuong-98/) · [Chương 102](https://vietnamthuquan.eu/TacPham/co-chan-nhan-25730/chuong-102) · [Chương 130](https://truyenfull.live/co-chan-nhan/chuong-130/)

## Thứ tự triển khai

1. Luyện trận dùng cùng bộ luật với Vượt Thanh Mao và tách bản lưu. Đây là nơi thử từng Cổ và cách đánh trùm.
2. Luyện trận và phần thưởng dùng chung luật Ngọc Bì Cổ và Sinh Cơ Diệp. Gemini bàn giao nguồn chỉnh sửa, icon, atlas và clip duyệt hai hiệu ứng trên nhánh riêng.
3. Ba bố cục vách che, đòn lao theo hàng và điểm nghỉ đã vào luật lưu v3. Gemini phụ trách viền vách và hình báo đòn ở đúng cỡ chơi. Các lượt đang chơi ở v1/v2 giữ luật đã dùng khi bắt đầu.
4. Hai đòn và nhịp hồi của Cuồng Điện Lang đã có trong lượt chính và Luyện trận. Kết quả dò đường thắng là mốc kiểm bố cục. Duyệt nhịp di chuyển, báo đòn và hiệu ứng trong Godot trước khi chốt cân bằng.
5. Chọn bộ Nhị chuyển sau khi thắng Cuồng Điện Lang. Chín cặp dùng được trong lượt mới và Luyện trận. Gemini làm atlas Nguyệt Mang và Bạch Ngọc trên nhánh asset riêng.
6. Nối Bãi Đá Suối Sấm, cho đổi bộ giữa hai màn và thêm hệ Tửu. Lượt v4 tiếp tục giữ luật cũ ở Sườn đá Mù Sương và nhận luật mới ở Suối Sấm. Gemini phụ trách atlas Tửu Trùng, Tứ Vị Tửu Trùng và ô nước nông có dấu nhiễm điện.
7. Nối Hẻm Đá Phục Kích và hệ Ẩn. Lượt v4/v5 giữ luật đã áp dụng trong hai màn trước khi tiếp tục vào hẻm. Gemini làm hiệu ứng hai Cổ hệ Ẩn và mẫu ô nứt/đá rơi trên nhánh asset riêng.
8. Thêm điểm dừng, nguyên thạch trong túi, thương nhân và bảo vật cho lượt v7. Xem chi phí và kết quả dự kiến ở mức sinh lực, chân nguyên và số lá thực tế trước khi xác nhận.
9. Thêm Ổ Điện Lang vào điểm dừng sau Suối Sấm ở lượt v8. Thắng trận phụ mở một lựa chọn chiến lợi phẩm rồi đưa người chơi về Hẻm Đá.
10. Mở Lôi Nha Đài ở lượt v9 sau Hẻm Đá Phục Kích. Cả hai đường dùng chung điểm chuẩn bị. Thắng boss nhận Ấn Trấn Lôi và mở trận luyện riêng.
9. Nối atlas Cổ, ô địa hình và dấu báo đòn Gemini đã bàn giao vào lượt chính và Luyện trận. Kiểm nhịp ra Cổ, thời điểm đổi chỉ số trên HUD và hình dấu đúng ô.

## Bộ Cổ ở Nhị chuyển

Mỗi màn thử cấp một Cổ Nhị chuyển và một Cổ Nhất chuyển để lắp thành cặp. Giá trị sinh lực, chân nguyên và số lá chuyển sang được hiển thị trước khi xác nhận. Có thể chọn lại cặp ở hai điểm nghỉ. Luyện trận có cả bốn hệ.

| Hệ | Cặp cùng hệ | Cách đánh trong demo |
| --- | --- | --- |
| Nguyệt | Nguyệt Quang Cổ + Nguyệt Mang Cổ | Nguyệt Quang đặt Nguyệt Ấn. Nguyệt Mang có tầm 6 ô, tốn 3 chân nguyên, gây 30 sát thương và thêm 12 khi tiêu ấn. Chỉ một ấn bám trên địch và giữ đến khi bị tiêu hoặc trận kết thúc. |
| Hộ thể | Ngọc Bì Cổ + Bạch Ngọc Cổ | Luật v5 cho Bạch Ngọc chặn 11 sát thương của đòn kế tiếp trong ba lượt, tốn 2 chân nguyên. Thay lớp Ngọc Bì đang hoạt động tăng sức chặn lên 15 và chỉ tốn 1 chân nguyên. Lớp Bạch Ngọc của bộ này chặn được sát thương thì cú Tay không kế tiếp được cộng 10 sát thương. |
| Tửu | Tửu Trùng + Tứ Vị Tửu Trùng | Tửu Trùng hồi tối đa 2 chân nguyên, dùng được hai lần mỗi trận. Tứ Vị tốn 2 chân nguyên để cộng 12 sát thương cho cú Tay không kế tiếp. Dùng Tửu Trùng trước khi kích Tứ Vị cho hai cú được cường hóa. |
| Ẩn | Ẩn Thạch Cổ + Ẩn Lân Cổ | Ẩn Thạch tốn 1 chân nguyên và chuẩn bị lần Di chuyển tối đa ba ô. Ẩn Lân tốn 2 chân nguyên, làm trượt một lần địch nhắm trực tiếp trong hai lượt đáp trả tính cả lượt kích hoạt. Sau khi chuẩn bị bằng Ẩn Thạch, lần kích Ẩn Lân kế tiếp tốn 1 chân nguyên và nâng lần Di chuyển lên bốn ô. Đá rơi và nước nhiễm điện vẫn gây sát thương khi đứng trong vùng. |
| Phối hệ | 12 cặp khác hệ | Dùng tác dụng cơ bản của từng Cổ. Ví dụ dùng Ẩn Thạch để vào tầm Nguyệt Mang, Ẩn Lân để né đòn nhắm trực tiếp trong bộ có Tửu Trùng, hoặc Ngọc Bì để chuẩn bị cho sát thương diện rộng. |

Sinh Cơ Diệp là vật phẩm trị thương dùng chung với cả bốn hệ. Màn thử cấp sẵn cặp Cổ. Khi làm hệ thống hợp luyện, chương 98 là cơ sở cho hai bí phương: Nguyệt Quang và hai Tiểu Quang tạo Nguyệt Mang, Bạch Thỉ và Ngọc Bì tạo Bạch Ngọc. Chương 100 mô tả lớp phòng hộ trắng mỏng của Bạch Ngọc mạnh hơn Ngọc Bì. Hiệu ứng bộ, Phản đòn và các con số trong bảng là luật thiết kế của demo. [Chương 98](https://truyenhoan.com/co-chan-nhan/chuong-98.html) · [Chương 100](https://tangthuvienhd.com/truyen/co-chan-nhan/chuong-100.html)

Chương 225 mô tả Tửu Trùng tinh luyện chân nguyên của cổ sư Nhất chuyển. Chương 121 mô tả Tứ Vị Tửu Trùng tinh luyện chân nguyên Nhị chuyển. Tên hệ Tửu, cách hồi chân nguyên theo lượt và cách cường hóa Tay không là thiết kế riêng của demo. [Chương 121](https://tangthuvienhd.com/truyen/co-chan-nhan/chuong-121.html) · [Chương 225](https://truyenfull.live/co-chan-nhan/chuong-225/)

Chương 116 và 121 ghi Ẩn Thạch là Nhất chuyển, chỉ giấu thân thể. Ẩn Lân là Nhị chuyển, có thể giấu cả y phục. Chương 130 mô tả Điện Lang mất dấu khi Phương Nguyên dùng Ẩn Lân. Tầm di chuyển, số lượt che thân và phân nhóm hệ Ẩn thuộc luật demo. [Chương 116](https://truyenhoan.com/co-chan-nhan/chuong-116.html) · [Chương 121](https://tangthuvienhd.com/truyen/co-chan-nhan/chuong-121.html) · [Chương 130](https://tangthuvienhd.com/truyen/co-chan-nhan/chuong-130.html)

Kiểm thử v5 đi hết hai màn Nhị chuyển với 108 tổ hợp gồm chín bộ, bốn bậc tư chất và ba cặp bố cục. Khi phát lại đúng 12 chuỗi hành động có dùng Bạch Ngọc của v4 trên luật v5, bộ Hộ thể thắng với thêm 3–6 sinh lực ở Sườn đá Mù Sương. Một đường thắng thử của bộ Hộ thể ở Suối Sấm còn 5 sinh lực.

Kiểm thử v6 tìm được đường thắng ở Hẻm Đá cho 192 tổ hợp gồm 16 cặp, bốn bậc tư chất và ba bố cục. Trong phép tìm đường thắng sớm, bộ Nguyệt thuần thắng sau 4–6 lượt và có trường hợp chỉ còn 4 sinh lực. Ba bộ thuần còn lại thắng sau 9 lượt, thấp nhất 7 sinh lực. Phép thử Đinh đẳng ưu tiên bảo toàn sinh lực trong 13 lượt tìm được đường dùng Ẩn Lân giữ nguyên sinh lực ở cả ba bố cục. Mười sáu cặp cũng qua cả ba màn Nhị chuyển ở một lượt Đinh đẳng cố định.

Khi thêm hệ mới, chuẩn bị ít nhất hai Cổ có vai trò bổ sung và một lựa chọn phối hệ. Chốt tương tác trong Luyện trận trước khi đưa cả bộ vào chiến lợi phẩm. Địa Thính Nhục Nhĩ Thảo phù hợp một nhánh do thám khi đã có màn phục kích và đường đi để người chơi tận dụng.

## Điểm dừng roguelike

*Slay the Spire* cho chọn đường an toàn hay rủi ro và mang di vật theo lượt. Vượt Thanh Mao áp dụng quyết định đó ở hai điểm dừng giữa ba trận, với một ô bảo vật để dễ đọc ảnh hưởng của món đang mang. [Slay the Spire · Mega Crit](https://store.steampowered.com/app/646570/Slay_the_Spire/)

*Wildfrost* kết hợp chọn đường và bùa hỗ trợ đội hình. Trong Vượt Thanh Mao, bảo vật bổ sung lựa chọn cho cả bộ thuần và phối hệ. Chúng tác động vào lần di chuyển đầu, đòn trúng đầu hoặc chân nguyên lúc vào trận. [Wildfrost · Deadpan Games và Gaziter](https://store.steampowered.com/app/1811990/Wildfrost/)

*Into the Breach* cho thấy ý định địch trước lượt. Vượt Thanh Mao dùng cùng nguyên tắc cung cấp thông tin cho hai điểm dừng, hiển thị giá, tài nguyên trước và sau khi chọn, cùng cảnh báo địa hình của trận kế tiếp. [Into the Breach · Subset Games](https://store.steampowered.com/app/590380/Into_the_Breach/)

| Lựa chọn | Hiệu ứng ở lượt v7 |
| --- | --- |
| Lều nghỉ | Hồi thêm tối đa 6 sinh lực sau phần hồi lúc chuyển màn. |
| Túi bên bờ đá | Có sau Sườn đá Mù Sương. Mất 8 sinh lực để nhận 3 nguyên thạch. |
| Mạch nước trong khe | Có sau Suối Sấm. Tốn 2 chân nguyên để lấy một Sinh Cơ Diệp. |
| Quầy đổi đồ | Một Sinh Cơ Diệp giá 3 và một bảo vật giá 4 nguyên thạch. Đổi bảo vật đang mang tốn 2. Mỗi món mua tối đa một lần tại mỗi quầy. Hàng bảo vật theo mã lượt và đổi khi sang điểm dừng thứ hai. |

Thắng Sườn đá Mù Sương nhận 4 nguyên thạch. Thắng Suối Sấm nhận 2. Mua bảo vật mới thay món đang mang. Giày cỏ lau thêm một ô cho lần Di chuyển đầu mỗi trận, có thể cộng với bước ẩn. Ngọc bài hộ thân chặn tối đa 3 sát thương còn lại của đòn đầu còn gây sát thương sau Thủ thế và lớp ngọc. Trâm tụ nguyên thêm 1 chân nguyên đầu trận đến mức sức chứa. Túi nguyên thạch và bảo vật thuộc lượt hiện tại.

Kiểm 48 lượt v7 gồm bốn bộ thuần, ba mã lượt và bốn cách kết hợp điểm dừng. Có đường thắng khi nghỉ cả hai lần, nhặt nguyên thạch rồi mua cả hai món ở quầy, mua bảo vật rồi đổi chân nguyên lấy lá, hoặc đổi bảo vật giữa hai trận. Khi tải lại, cửa hàng giữ đúng món đã mua và chi phí đã trả.

## Ổ Điện Lang

Sau Bãi Đá Suối Sấm, chọn săn tinh anh thay cho lều nghỉ, quầy đổi đồ hoặc mạch nước. Ổ Điện Lang có ba bố cục đá chặn theo mã lượt. Điện Lang đầu đàn có 96 sinh lực, cắn 12 sát thương và luân phiên vồ vùng hoặc lao xuyên hàng với 21 sát thương. Sau mỗi đòn lớn, đầu đàn đứng hồi thế một lượt để người chơi có cơ hội đổi vị trí hoặc phản công.

Thắng trận hồi tối đa 16 sinh lực và 3 chân nguyên, sau đó chọn một trong hai món. **Nanh Tinh Anh** chiếm ô bảo vật và thêm 8 sát thương cho đòn Tay không, Nguyệt Quang hoặc Nguyệt Mang đầu tiên gây sát thương mỗi trận. **Túi dược của thợ săn** giữ bảo vật đang mang, hồi thêm tối đa 10 sinh lực và thêm một Sinh Cơ Diệp. Sinh lực, chân nguyên và vật phẩm sau khi nhận được hiển thị trên từng thẻ. Có thể đổi bộ trước khi vào Hẻm Đá.

Việc chọn nhánh, đánh tinh anh và nhận thưởng đều lưu trong nhật ký. Phát lại nhật ký kiểm tra hành động theo đúng pha, gồm quyền nhận thưởng một lần và thua trận khi gục trong ổ.

Phép tìm đường thắng ưu tiên kết thúc sớm kiểm 192 tổ hợp từ cùng điểm dừng, gồm 16 cặp Cổ, bốn tư chất và ba bố cục. Cả 192 tổ hợp có đường thắng ở Hẻm Đá khi đi qua lều nghỉ, và cũng có đường hạ tinh anh rồi qua Hẻm Đá với từng phần thưởng. Ổ Điện Lang mất 6–17 lượt, trung bình 11,6. Lối qua lều mất 6–9 lượt, trung bình 8,0, để thắng Hẻm Đá.

| Bộ thuần | Lượt để hạ tinh anh | Sinh lực còn lại |
| --- | --- | --- |
| Nguyệt | 6–9 | 18–41 |
| Hộ thể | 11–13 | 3–23 |
| Tửu | 11–15 | 2–44 |
| Ẩn | 13–17 | 4–32 |

Nanh giúp kết thúc Hẻm Đá sớm hơn lối qua lều trong 76/192 tổ hợp. Túi dược cho sinh lực vào Hẻm Đá cao hơn Nanh trong 164/192 tổ hợp và cho sinh lực thấp nhất sau Hẻm Đá là 7, so với 1 khi chọn Nanh. Các số này mô tả đường thắng tìm được, phụ thuộc tài nguyên ở điểm dừng và cách chọn hành động.

## Lôi Nha Đài

Sau Hẻm Đá, người chơi hồi tối đa 32 sinh lực và 4 chân nguyên, mang lá và bảo vật còn lại rồi chọn bộ Cổ. Ba bố cục được chọn theo mã lượt. Lôi Nha Trấn Ải có 108 sinh lực. Trong tầm năm ô, boss báo quét cả hàng có nhân vật và gây 20 sát thương. Từ 54 sinh lực trở xuống, lần báo tiếp theo phủ cả hàng và cột, gây 24 sát thương. Các ô đá bị loại khỏi vùng tím. Đòn đã báo chốt theo vị trí đầu lượt. Để né chữ thập, đi hai bước đổi cả hàng lẫn cột. Ngoài tầm điện, boss áp sát.

Sau mỗi đòn điện, boss hở lôi giáp đúng một lượt. Tay không, Nguyệt Quang và Nguyệt Mang trúng trong lượt này gây thêm tối đa 5 sát thương. Nanh Tinh Anh vẫn cộng cho đòn trúng đầu trận và cả hai hiệu ứng được tính trước khi địch đáp trả. Đòn vùng có thể chịu bằng Thủ thế hoặc lớp ngọc. Ẩn Lân làm trượt các đòn nhắm mục tiêu theo luật hiện có.

Hạ boss nhận Ấn Trấn Lôi tự động trong bản lưu cục bộ. Ấn mở Lôi Nha Trấn Ải trong Luyện trận, vẫn hiện khi bắt đầu lượt mới và dùng chung cho cả hai nhân vật. Luyện trận giữ tiến độ chính tách riêng. Bản lưu v8 giữ nguyên nhật ký. Ở màn kết quả Hẻm Đá, người chơi có thể bắt đầu lượt mới hoặc vào Lôi Nha Đài để chuyển lượt hiện tại sang v9.

Phép tìm đường thắng ưu tiên kết thúc sớm, bắt đầu từ cùng trạng thái sau Bãi Đá Suối Sấm và giữ cùng cặp Cổ trên mỗi lộ trình. Với 16 cặp Cổ, bốn tư chất và ba bố cục, mỗi lối đều có đường thắng ở 192 cấu hình. Tổng lượt tính từ sau Suối Sấm gồm Hẻm Đá, boss và trận phụ nếu đã săn tinh anh.

| Lối đi | Thắng | Lượt đánh boss | Lượt đánh boss trung bình | Tổng lượt trung bình |
| --- | --- | --- | --- | --- |
| Lều nghỉ → Hẻm Đá | 192/192 | 4–13 | 9,31 | 17,31 |
| Ổ Điện Lang → Nanh Tinh Anh | 192/192 | 5–12 | 8,78 | 27,92 |
| Ổ Điện Lang → Túi dược | 192/192 | 4–13 | 9,41 | 28,95 |

Nanh rút số lượt đánh boss ở 134/192 cặp so sánh với lối qua lều. Lối qua lều vẫn ngắn hơn về tổng số lượt trung bình. Đây là kết quả tìm đường thắng từ các trạng thái đã chọn, phụ thuộc trang bị và hành động trong từng lượt.

Kiểm thêm 48 cấu hình ở trận boss với 33 sinh lực, 4 chân nguyên, túi trống và Nguyệt Quang chưa luyện. Cả 16 cặp Cổ ở cả ba bố cục đều có đường thắng trong 8–13 lượt. Đường thắng còn ít sinh lực nhất kết thúc ở 5 sinh lực.

## Đồ họa trong trận

Godot dùng các khung của bảy Cổ và Sinh Cơ Diệp cho cả Huyền bào và Áo rêu. Nguyệt Mang bay theo hàng riêng khi có Nguyệt Ấn. Ngọc Bì và Bạch Ngọc có khung tụ, duy trì và va chạm riêng. Tứ Vị đổi dấu sáng theo số lần tăng lực còn lại. Khi Ẩn Lân làm đòn nhắm trượt, Điện Lang hiện dấu mất mục tiêu đúng nhịp. Sinh lực tăng ở khung trị thương Sinh Cơ Diệp và chân nguyên tăng tại khung Tửu Trùng có hiệu lực.

Mặt nước Suối Sấm nối theo bốn cạnh của các ô nước đã lưu. Dấu điện tím chỉ phủ các ô đang bị đòn khóa. Hẻm Đá vẽ ô nứt đi được và đá chặn theo dữ liệu bàn, đồng thời dùng dấu hổ phách cho đá rơi. Hàng lao của tinh anh và quét của Cuồng Điện Lang dùng chung hệ dấu theo hướng và bỏ qua ô đá.

PNG và thiết lập nhập của Godot nằm ở các thư mục asset tương ứng. Nguồn chỉnh sửa, bảng khung và ảnh duyệt được lưu tại các commit bàn giao. [Ngọc Bì và Sinh Cơ](https://github.com/whaticando0110/cochannhan-web-demo/commit/971abaa) · [Nguyệt Mang và Bạch Ngọc](https://github.com/whaticando0110/cochannhan-web-demo/commit/5205ab5) · [Tửu và Suối Sấm](https://github.com/whaticando0110/cochannhan-web-demo/commit/d42a56a) · [Ẩn và Hẻm Đá](https://github.com/whaticando0110/cochannhan-web-demo/commit/d19a143) · [Vách che và đòn theo hàng](https://github.com/whaticando0110/cochannhan-web-demo/commit/f5fc683)

<details>
<summary>Kế hoạch của bản thử thú triều trước đây</summary>

Tài liệu này ghi kế hoạch của bản thử thú triều. Hướng web hiện hành là [roguelike theo lượt](../README.md), dùng lại Đại điển Khai Khiếu làm phần mở đầu.

Bản hiện tại chơi được từ Đại điển Khai Khiếu qua cảnh Cuồng Điện Lang đánh lũy, báo tin ở hậu trại và theo đội trưởng qua đường rừng đến cuộc chạm trán một con sói. Bản đồ 42 × 26 ô đã có tìm đường, đi bộ, chạy, lối giữa cầu thang và giao chiến thời gian thực. Trận Đấu nhanh ở Thềm Hứng Mây giữ chế độ đánh theo lượt.

## Mạch của bản demo

Chọn giới tính và Cổ nhất chuyển → Khai Khiếu, hiện tư chất → Sơn Trại trong thú triều → theo đồng đội qua lối hông → cùng NPC đánh đợt sói đầu → Sói Vương áp sát → rút lui, đồng đội đỡ đòn → rơi xuống vách núi → thử một tương tác truyền thừa → cảnh kết.

Kịch bản mở đầu nối lễ Khai Khiếu sang thú triều bằng một đoạn chuyển thời gian ngắn. Tĩnh Nghi đưa người chơi qua bài học phòng thủ, rồi sai đi gọi viện binh khi Cuồng Điện Lang xuất hiện. Đội trưởng phái hai cổ sư lên lũy và dẫn người chơi qua cổng đông bên hông tới điểm tập kết. Kịch bản tiếp theo đặt đội viện trợ đang phá vòng vây trong rừng. Một Điện Lang tách đàn phát hiện người chơi và mở trận hướng dẫn theo lượt. Sau trận, người chơi tới nói chuyện với đội. [Brief Sơn Trại trong thú triều](brief-co-nguyet-son-trai.md) · [Bố cục rừng để duyệt](forest-ambush/README.md)

## Thứ tự làm

| Mốc | Phần làm | Điều kiện hoàn thành |
| --- | --- | --- |
| 1 | Dựng luồng dẫn truyện từ màn chọn nhân vật đến trận sói hiện có bằng các cảnh ngắn. Nối giới tính, Cổ đã chọn và tư chất vào trạng thái người chơi. | Chơi được từ màn mở đầu đến lượt đầu của trận. Nút chơi lại đưa về đầu, còn thử lại trận giữ lựa chọn ban đầu. |
| 2 | Dựng Sơn Trại lúc thú triều từ tileset đang có. Thêm dấu hiệu giao chiến trên lũy, đồng đội ở ngã rẽ và lối hông ra rừng. | Người chơi nhìn ra đường cần đi, có thể khám phá sân và lũy, đến điểm hẹn bằng phím hoặc cảm ứng. |
| 3 | Thấy đội viện trợ phá vây. Một Điện Lang phát hiện người chơi, mở bài hướng dẫn đánh theo lượt. | Cả hai skin chơi được từ lúc thấy đội tới sau trận và tương tác với đội viện trợ. Hướng dẫn bám hành động và ý định thật của đối thủ. |
| 4 | Sói Vương xuất hiện sau đợt đầu. Mục tiêu đổi sang rút lui và hiện ô thoát. Tại đó, đồng đội đỡ đòn rồi nhân vật rơi xuống vách núi. | Người chơi nhìn thấy mục tiêu mới và tự điều khiển tới lối thoát. Cảnh rơi phát một lần rồi chuyển vị trí sang khu truyền thừa. |
| 5 | Dựng khoang truyền thừa và một tương tác có kết quả rõ ràng. Phát cảnh kết rồi hiện lựa chọn chơi lại. | Có thể hoàn thành toàn bộ demo từ lần vào đầu tiên đến cảnh kết bằng bàn phím hoặc cảm ứng. |

## Việc cụ thể đầu tiên

- Map Đại điển Khai Khiếu được dựng trước dưới dạng màn chơi riêng, với vườn Nguyệt Lan, áp lực nguyên khí và tư chất tính theo độ sâu. [Luật và nguồn truyện](dai-dien-khai-khieu.md)
- Phác ba màn theo thứ tự **Chọn nhân vật → Chọn Cổ nhất chuyển → Khai Khiếu**. Hai giới tính hiển thị cùng một bộ thông tin. Mẫu nam dùng Huyền bào, mẫu nữ lấy từ bộ đã duyệt trước khi nối vào game.
- Nối kết quả Đại điển vào hồ sơ nhân vật và hiện tác dụng cụ thể trên thanh chân nguyên. Chốt danh sách Cổ nhất chuyển từ dữ liệu dự án trước khi gắn chỉ số.
- Nối cảnh Khai Khiếu với điểm xuất phát trên map hiện có. Chèn báo động và mục tiêu gặp đồng đội làm tín hiệu chuyển cảnh.
- Thử hai giới tính, mỗi Cổ khởi đầu, chơi lại và thử lại trận trên máy tính và điện thoại trước khi dựng các cảnh tiếp theo.

</details>
