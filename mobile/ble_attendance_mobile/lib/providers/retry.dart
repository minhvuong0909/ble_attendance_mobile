/// Riverpod 3 tự thử lại provider lỗi nhiều lần; app hiển thị lỗi kèm nút "Thử lại"
/// nên tắt cơ chế đó để người dùng thấy lỗi ngay và tự quyết định.
Duration? noAutoRetry(int retryCount, Object error) => null;
