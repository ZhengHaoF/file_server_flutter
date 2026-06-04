import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/network_log_service.dart';

class NetworkLogDialog extends StatefulWidget {
  const NetworkLogDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const NetworkLogDialog(),
    );
  }

  @override
  State<NetworkLogDialog> createState() => _NetworkLogDialogState();
}

class _NetworkLogDialogState extends State<NetworkLogDialog> {
  final NetworkLogService _service = NetworkLogService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final logs = _service.logs;

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            _buildHeader(logs.length),
            const Divider(height: 1),
            if (logs.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('暂无网络请求', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _LogTile(entry: logs[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const Icon(Icons.bug_report, size: 20),
          const SizedBox(width: 8),
          Text('网络日志 ($count)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          Row(
            children: [
              const Text('记录', style: TextStyle(fontSize: 12)),
              Switch(
                value: _service.enabled,
                onChanged: (v) => _service.enabled = v,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: count == 0 ? null : _service.clear,
          ),
          IconButton(
            tooltip: '关闭',
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final NetworkLogEntry entry;

  const _LogTile({required this.entry});

  Color get _statusColor {
    if (entry.isRequestError) return Colors.red;
    final code = entry.statusCode ?? 0;
    if (code >= 200 && code < 300) return Colors.green;
    if (code >= 300 && code < 400) return Colors.orange;
    if (code >= 400) return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.method,
                style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              entry.statusCode?.toString() ?? 'ERR',
              style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                entry.url,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Text('${entry.durationMs}ms', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            entry.timestamp.toIso8601String().substring(11, 23),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        children: [
          _DetailSection(
            title: '请求头',
            content: entry.formattedRequestHeaders,
            copyText: entry.formattedRequestHeaders,
          ),
          _DetailSection(
            title: '请求体',
            content: entry.formattedRequestBody,
            copyText: entry.formattedRequestBody,
          ),
          _DetailSection(
            title: '响应头',
            content: entry.formattedResponseHeaders,
            copyText: entry.formattedResponseHeaders,
          ),
          _DetailSection(
            title: '响应体',
            content: entry.formattedResponseBody,
            copyText: entry.formattedResponseBody,
          ),
          if (entry.error != null)
            _DetailSection(
              title: '错误',
              content: entry.error!,
              copyText: entry.error,
              highlight: true,
            ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final String content;
  final String? copyText;
  final bool highlight;

  const _DetailSection({
    required this.title,
    required this.content,
    this.copyText,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
              const Spacer(),
              InkWell(
                onTap: () {
                  if (copyText == null) return;
                  Clipboard.setData(ClipboardData(text: copyText!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制'), duration: Duration(milliseconds: 800)),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 12, color: Colors.grey),
                      SizedBox(width: 2),
                      Text('复制', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: highlight ? Colors.red.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: highlight ? Colors.red.shade200 : Colors.grey.shade300,
                width: 0.5,
              ),
            ),
            child: SelectableText(
              content,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: highlight ? Colors.red.shade700 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
