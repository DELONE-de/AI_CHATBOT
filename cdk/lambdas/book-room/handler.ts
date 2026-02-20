import { closeIntent } from '../shared/lex-response';
import { escalateToHuman } from '../shared/human-handoff';

export const handler = async (event: any) => {
  console.log('book-room invoked:', JSON.stringify(event));

  return closeIntent(
    event,
    'This request has been forwarded to a hotel agent.',
    escalateToHuman()
  );
};
