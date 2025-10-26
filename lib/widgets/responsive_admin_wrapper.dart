import 'package:flutter/material.dart';

/// A responsive wrapper widget that provides consistent responsive behavior
/// across all admin screens, matching the admin dashboard pattern.
class ResponsiveAdminWrapper extends StatelessWidget {
  final Widget child;
  final double mobileBreakpoint;
  final double tabletBreakpoint;

  const ResponsiveAdminWrapper({
    super.key,
    required this.child,
    this.mobileBreakpoint = 600,
    this.tabletBreakpoint = 900,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(_getPadding(constraints.maxWidth)),
          child: child,
        );
      },
    );
  }

  double _getPadding(double width) {
    if (width < mobileBreakpoint) return 12.0;
    if (width < tabletBreakpoint) return 16.0;
    return 24.0;
  }
}

/// Responsive card layout that switches between column (mobile) and row (desktop)
class ResponsiveCardLayout extends StatelessWidget {
  final List<Widget> children;
  final double breakpoint;
  final double spacing;

  const ResponsiveCardLayout({
    super.key,
    required this.children,
    this.breakpoint = 600,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          // Mobile: Vertical layout
          return Column(
            children: _intersperse(children, SizedBox(height: spacing)),
          );
        } else {
          // Desktop: Horizontal scroll
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _intersperse(children, SizedBox(width: spacing)),
            ),
          );
        }
      },
    );
  }

  List<Widget> _intersperse(List<Widget> list, Widget separator) {
    if (list.isEmpty) return [];
    return list.expand((item) => [item, separator]).toList()..removeLast();
  }
}

/// Responsive data table that switches to card view on mobile
class ResponsiveDataView extends StatelessWidget {
  final List<String> headers;
  final List<List<dynamic>> rows;
  final List<Widget> Function(dynamic row)? rowActions;
  final double breakpoint;

  const ResponsiveDataView({
    super.key,
    required this.headers,
    required this.rows,
    this.rowActions,
    this.breakpoint = 600,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          // Mobile: Card view
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              return _buildMobileCard(context, rows[index], index);
            },
          );
        } else {
          // Desktop: Table view
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
              rows: rows.asMap().entries.map((entry) {
                return _buildDataRow(entry.value, entry.key);
              }).toList(),
            ),
          );
        }
      },
    );
  }

  Widget _buildMobileCard(BuildContext context, List<dynamic> row, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < headers.length && i < row.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        '${headers[i]}:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: _buildCellContent(row[i]),
                    ),
                  ],
                ),
              ),
            if (rowActions != null) ...[
              const Divider(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: rowActions!(row),
              ),
            ],
          ],
        ),
      ),
    );
  }

  DataRow _buildDataRow(List<dynamic> row, int index) {
    final cells = row.map((cell) => DataCell(_buildCellContent(cell))).toList();
    if (rowActions != null) {
      cells.add(DataCell(
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: rowActions!(row),
        ),
      ));
    }
    return DataRow(cells: cells);
  }

  Widget _buildCellContent(dynamic cell) {
    if (cell is Widget) return cell;
    return Text(cell?.toString() ?? '');
  }
}

/// Responsive button bar that wraps on mobile
class ResponsiveButtonBar extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment alignment;
  final double spacing;

  const ResponsiveButtonBar({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.start,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Mobile: Wrap buttons
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: _getWrapAlignment(alignment),
            children: children,
          );
        } else {
          // Desktop: Row
          return Row(
            mainAxisAlignment: alignment,
            children: _intersperse(children, SizedBox(width: spacing)),
          );
        }
      },
    );
  }

  WrapAlignment _getWrapAlignment(MainAxisAlignment mainAxis) {
    switch (mainAxis) {
      case MainAxisAlignment.start:
        return WrapAlignment.start;
      case MainAxisAlignment.end:
        return WrapAlignment.end;
      case MainAxisAlignment.center:
        return WrapAlignment.center;
      case MainAxisAlignment.spaceBetween:
        return WrapAlignment.spaceBetween;
      default:
        return WrapAlignment.start;
    }
  }

  List<Widget> _intersperse(List<Widget> list, Widget separator) {
    if (list.isEmpty) return [];
    return list.expand((item) => [item, separator]).toList()..removeLast();
  }
}

