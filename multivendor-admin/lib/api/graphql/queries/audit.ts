import { gql } from '@apollo/client';

export const GET_AUDIT_LOGS = gql`
  query AuditLogs($page: Int, $limit: Int, $search: String) {
    auditLogs(page: $page, limit: $limit, search: $search) {
      auditLogs {
        _id
        timestamp
        admin {
          _id
          email
        }
        action
        targetType
        targetId
        changes
      }
      totalCount
      currentPage
      totalPages
    }
  }
`;
