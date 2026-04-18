/// Query builder for Firestack document queries.
///
/// Mirrors the where-clause filtering supported by the API:
/// ```dart
/// final query = QueryBuilder()
///   .where('age', isGreaterThan: 18)
///   .where('status', isEqualTo: 'active')
///   .orderBy('created_at', descending: true)
///   .limit(10)
///   .page(2)
///   .select(['name', 'email', 'age']);
/// ```
class QueryBuilder {
  final Map<String, dynamic> _where = {};
  String _orderBy = 'created_at';
  String _orderDir = 'desc';
  int _perPage = 15;
  int _page = 1;
  List<String>? _select;
  String? _search;

  /// Add a where filter.
  QueryBuilder where(
    String field, {
    dynamic isEqualTo,
    dynamic isNotEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    String? like,
    List<dynamic>? whereIn,
    List<dynamic>? whereNotIn,
    dynamic arrayContains,
    bool? isNull,
  }) {
    if (isEqualTo != null) {
      _where[field] = {'op': 'eq', 'value': isEqualTo};
    } else if (isNotEqualTo != null) {
      _where[field] = {'op': 'ne', 'value': isNotEqualTo};
    } else if (isLessThan != null) {
      _where[field] = {'op': 'lt', 'value': isLessThan};
    } else if (isLessThanOrEqualTo != null) {
      _where[field] = {'op': 'lte', 'value': isLessThanOrEqualTo};
    } else if (isGreaterThan != null) {
      _where[field] = {'op': 'gt', 'value': isGreaterThan};
    } else if (isGreaterThanOrEqualTo != null) {
      _where[field] = {'op': 'gte', 'value': isGreaterThanOrEqualTo};
    } else if (like != null) {
      _where[field] = {'op': 'like', 'value': like};
    } else if (whereIn != null) {
      _where[field] = {'op': 'in', 'value': whereIn.join(',')};
    } else if (whereNotIn != null) {
      _where[field] = {'op': 'not-in', 'value': whereNotIn.join(',')};
    } else if (arrayContains != null) {
      _where[field] = {'op': 'array-contains', 'value': arrayContains};
    } else if (isNull != null) {
      _where[field] = {'op': isNull ? 'is_null' : 'is_not_null', 'value': ''};
    }
    return this;
  }

  /// Set the order-by field.
  QueryBuilder orderBy(String field, {bool descending = false}) {
    _orderBy = field;
    _orderDir = descending ? 'desc' : 'asc';
    return this;
  }

  /// Set the number of results per page.
  QueryBuilder limit(int perPage) {
    _perPage = perPage;
    return this;
  }

  /// Set the page number (1-based).
  QueryBuilder page(int page) {
    _page = page;
    return this;
  }

  /// Select specific fields to return (projection).
  ///
  /// ```dart
  /// .select(['name', 'email']) // only return name and email in data
  /// ```
  QueryBuilder select(List<String> fields) {
    _select = fields;
    return this;
  }

  /// Full-text search across document data fields.
  QueryBuilder search(String query) {
    _search = query;
    return this;
  }

  /// Build query parameters map for API request.
  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{
      'per_page': _perPage.toString(),
      'page': _page.toString(),
      'order_by': _orderBy,
      'order_dir': _orderDir,
    };
    if (_where.isNotEmpty) {
      params['where'] = _where;
    }
    if (_select != null && _select!.isNotEmpty) {
      params['select'] = _select!.join(',');
    }
    if (_search != null && _search!.isNotEmpty) {
      params['search'] = _search;
    }
    return params;
  }
}
