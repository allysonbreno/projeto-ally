from typing import Optional, Dict, Any, Tuple


class Store:
    """Contrato da camada de persistência.
    Implementações: SqliteStore (agora), PostgresStore (futuro).
    """

    def create_tables(self) -> None:
        raise NotImplementedError

    # Users
    def get_user_by_username(self, username: str) -> Optional[Dict[str, Any]]:
        raise NotImplementedError

    def create_user(self, username: str, pwd_hash: Optional[bytes], salt: Optional[bytes]) -> str:
        """Retorna user_id (str). pwd_hash/salt podem ser None para fluxo legado sem senha."""
        raise NotImplementedError

    # Characters
    def get_character_by_user_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        raise NotImplementedError

    def get_character_by_name(self, character_name: str) -> Optional[Dict[str, Any]]:
        """Verifica se nome do personagem já existe."""
        raise NotImplementedError

    def create_character(self, user_id: str, name: str, character_type: str, defaults: Dict[str, Any]) -> str:
        """Cria character + attributes. character_type: 'warrior', 'mage', 'archer'. Retorna character_id."""
        raise NotImplementedError

    def load_character_full(self, user_id: str) -> Optional[Tuple[Dict[str, Any], Dict[str, Any]]]:
        """Retorna (character, attributes) pelo user_id."""
        raise NotImplementedError

    def save_character_state(self, character_id: str, state: Dict[str, Any]) -> None:
        raise NotImplementedError

    def save_character_attributes(self, character_id: str, attrs: Dict[str, int]) -> None:
        raise NotImplementedError

    def update_position(self, character_id: str, map_name: str, x: float, y: float) -> None:
        raise NotImplementedError

