import { gql } from '@apollo/client';

export const RESET_DEMO = gql`
  mutation ResetDemo {
    resetDemo
  }
`;
