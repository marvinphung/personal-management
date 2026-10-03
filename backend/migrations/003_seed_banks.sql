-- Migration 003_seed_banks.sql
-- Seed the four supported banks in qlt.bank_settings

INSERT INTO qlt.bank_settings (bank_code, enabled, receiver_account, receiver_name, instructions, version)
VALUES
    ('bidv', true, NULL, 'BIDV SmartBanking', 'Bật chia sẻ thông báo trong ứng dụng BIDV SmartBanking đến số tài khoản đã liên kết.', 1),
    ('vietinbank', true, NULL, 'VietinBank iPay', 'Bật tính năng chia sẻ biến động số dư iPay trong cài đặt ứng dụng VietinBank.', 1),
    ('vietcombank', true, NULL, 'VCB Digibank', 'Cài đặt thông báo OTT và chia sẻ biến động tài khoản trên VCB Digibank.', 1),
    ('techcombank', true, NULL, 'Techcombank Mobile', 'Kích hoạt nhận thông báo giao dịch chủ động trong ứng dụng Techcombank Mobile.', 1)
ON CONFLICT (bank_code) DO NOTHING;
